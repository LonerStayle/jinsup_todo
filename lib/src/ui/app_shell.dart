import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

import '../core/platform.dart';
import '../core/theme.dart';
import '../data/providers.dart';
import '../data/remote/supabase_realtime_sync.dart';
import '../domain/category.dart';
import '../features/add_todo/add_todo_controller.dart';
import '../features/add_todo/add_todo_sheet.dart';
import '../features/auth/auth_providers.dart';
import '../features/category/categories_controller.dart';
import '../features/category/category_view.dart';
import '../features/home/home_screen.dart';
import '../features/home/today_providers.dart';
import '../features/outline/outline_screen.dart';
import '../features/system/tray_service.dart';
import 'destination.dart';

/// 폼팩터 분기 컨테이너 + FAB (빠른 추가 트리거) + 1~5 카테고리 단축키.
///
/// 단축키: `0` = Today, `1` = work, `2` = personalDev, `3` = daily, `4` = longterm, `5` = idea.
/// macOS 데스크탑 global Cmd+N 은 phase 6 의 hotkey_manager task 에서 연결.
///
/// **시스템 단축키 비충돌 점검** (macOS):
///   - 우리가 잡는 modifier+key 조합은 **Cmd+N (글로벌)** 뿐. Cmd+W (Close window) /
///     Cmd+Q (Quit) / Cmd+M (Minimize) / Cmd+H (Hide) / Cmd+, (Preferences) 등은
///     macOS 가 그대로 처리하도록 둠.
///   - 0~5 는 modifier 없는 plain digit — TextField focus 시 [isFocusInEditableText] 가드로
///     숫자 입력에 양보 (text 입력 가능).
///   - Esc 는 AddTodoSheet 의 _DismissIntent (sheet 닫기) — macOS 의 dialog 닫기와
///     관행 일치, 충돌 없음.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;
  HotKey? _cmdN;
  TrayService? _tray;

  @override
  void initState() {
    super.initState();
    _registerGlobalHotkey();
    _initTray();
  }

  @override
  void dispose() {
    _unregisterGlobalHotkey();
    _tray?.dispose();
    super.dispose();
  }

  Future<void> _initTray() async {
    if (!AppPlatform.isDesktop) return;
    final tray = TrayService(
      onAddTodo: () {
        if (mounted) _openAddTodo();
      },
      onQuit: () {
        if (mounted) _confirmQuit();
      },
    );
    await tray.init();
    if (!mounted) {
      await tray.dispose();
      return;
    }
    _tray = tray;
  }

  /// tray menu 의 "종료" — outbox 가 비어 있으면 즉시 종료, pending 이 있으면 confirm dialog.
  /// 동기화되지 않은 변경은 다음 실행 시 자동 flush 되지만, 사용자가 그 사실을 알 수 있게.
  Future<void> _confirmQuit() async {
    final pending = ref.read(outboxCountProvider).value ?? 0;
    if (pending == 0) {
      await SystemNavigator.pop();
      return;
    }
    if (!mounted) return;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('종료할까요?'),
            content: Text(
              '아직 동기화되지 않은 변경 $pending건이 있어요.\n'
              '다음 실행 시 자동 동기화되지만 지금 끄면 잠시 동안 다른 기기에서 안 보일 수 있어요.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('종료'),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed) {
      await SystemNavigator.pop();
    }
  }

  Future<void> _registerGlobalHotkey() async {
    if (!AppPlatform.isDesktop) return;
    try {
      // `unregisterAll()` 은 hotkey_manager 의 process-scope 모든 hotkey 를 제거한다.
      // 다른 앱 영향은 없지만, 만약 향후 우리 앱이 hotkey 를 추가하면 함께 날아갈 위험이
      // 있어 **정확히 우리 단축키만** unregister 후 register 하는 형태로 안전화.
      final hotkey = HotKey(
        key: PhysicalKeyboardKey.keyN,
        modifiers: const [HotKeyModifier.meta],
        scope: HotKeyScope.system,
      );
      try {
        await hotKeyManager.unregister(hotkey);
      } catch (_) {
        // 등록 안 되어 있으면 무시 — register 만 진행.
      }
      await hotKeyManager.register(
        hotkey,
        keyDownHandler: (_) {
          if (mounted) _openAddTodo();
        },
      );
      _cmdN = hotkey;
    } catch (e) {
      // 글로벌 단축키 등록 실패 (test 환경 / 권한 거부) — FAB 으로 대체 가능하므로 fatal X.
      debugPrint('[solo_todo] Cmd+N 글로벌 단축키 등록 실패: $e');
    }
  }

  Future<void> _unregisterGlobalHotkey() async {
    final h = _cmdN;
    if (h == null) return;
    try {
      await hotKeyManager.unregister(h);
    } catch (_) {
      // 종료 단계 — 무시.
    }
  }

  /// build 마다 갱신되는 destinations — categoriesProvider 의 stream 으로 동기화.
  /// _selectByDigit / _openAddTodo 가 참조한다.
  List<AppDestination> _destinations = AppDestination.all;

  void _select(int i) {
    setState(() => _index = i);
  }

  /// 단축키 digit (0~9) → destination index 매핑. 0 Today, 1~min(9,N) 카테고리,
  /// N+1 (N<9 일 때) outline. 매칭 못 하면 no-op.
  void _selectByDigit(int digit) {
    final idx = _destinations.indexWhere((d) => d.shortcutDigit == digit);
    if (idx >= 0 && idx != _index) _select(idx);
  }

  Future<void> _openAddTodo() async {
    // _index 가 destinations 범위를 벗어났을 수 있으므로 safe lookup.
    final dest = (_index < _destinations.length)
        ? _destinations[_index]
        : _destinations.first;
    final initialCategory = dest.category ?? Category.daily;

    // sheet 가 닫힌 후 controller 를 호출해 결과(Calendar 경고 등)를 처리한다.
    AddTodoSubmission? submitted;
    await AddTodoSheet.show(
      context,
      initialCategory: initialCategory,
      onSubmit: (s) => submitted = s,
    );
    if (submitted == null || !mounted) return;

    final result = await ref.read(addTodoControllerProvider).add(submitted!);
    if (!mounted) return;
    final warning = result.calendarWarning;
    if (warning != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(warning), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 미체크 카운트가 바뀌면 tray title 갱신 (macOS 만 실효).
    ref.listen<int>(undoneTodayCountProvider, (_, next) {
      _tray?.updateUndoneCount(next);
    });

    // Supabase realtime sync — 인증된 user 가 있을 때만 활성. lifecycle 은 provider 가 관리.
    ref.watch(supabaseRealtimeSyncProvider);

    // user 가 다른 계정으로 바뀌면 옛 todos/outbox 자동 정리 (side-effect listener).
    ref.watch(userChangeCleanupProvider);

    // v1.2 — categoriesProvider 의 stream 에 따라 destinations 동적 build.
    // loading / error 시 fallback 으로 builtin 5종 기준의 default 사용.
    final categories =
        ref.watch(categoriesProvider).asData?.value ?? Category.builtinSeeds;
    _destinations = AppDestination.buildAll(categories);

    // _index 가 destinations.length 초과 (카테고리 삭제 직후 등) 면 Today (0) 으로 안전 fallback.
    final safeIndex = _index < _destinations.length ? _index : 0;
    final destination = _destinations[safeIndex];

    final fab = FloatingActionButton.extended(
      key: const ValueKey('add-todo-fab'),
      onPressed: _openAddTodo,
      icon: const Icon(Icons.add),
      label: const Text('추가'),
      tooltip: '새 할 일 (Cmd+N)',
    );

    final Widget body;
    if (AppPlatform.isDesktop) {
      body = Row(
        children: [
          _Sidebar(
            destinations: _destinations,
            selectedIndex: safeIndex,
            onSelect: _select,
          ),
          const VerticalDivider(width: AppTokens.hairline),
          Expanded(child: _MainArea(destination: destination)),
        ],
      );
    } else {
      body = SafeArea(child: _MainArea(destination: destination));
    }

    return _ShortcutsHost(
      destinations: _destinations,
      onSelect: _selectByDigit,
      child: Scaffold(
        floatingActionButton: fab,
        // 모바일은 NavigationBar 위에 자연스럽게 정렬되는 endContained — destination 라벨과
        // FAB 가 겹치지 않음. desktop 은 NavigationBar 자체가 없어 기본 endFloat.
        floatingActionButtonLocation: AppPlatform.isDesktop
            ? FloatingActionButtonLocation.endFloat
            : FloatingActionButtonLocation.endContained,
        body: body,
        // desktop 은 좌측 _Sidebar 가 네비게이션을 담당해 bottomNavigationBar 가 의도적으로
        // null. mobile 만 NavigationBar 노출.
        bottomNavigationBar: AppPlatform.isDesktop
            ? null
            : NavigationBar(
                selectedIndex: safeIndex,
                onDestinationSelected: _select,
                destinations: [
                  for (final d in _destinations)
                    NavigationDestination(
                      icon: Icon(d.icon),
                      label: d.label,
                      tooltip: d.tooltipWithShortcut,
                    ),
                ],
              ),
      ),
    );
  }
}

class _SelectDestinationIntent extends Intent {
  const _SelectDestinationIntent(this.digit);

  /// 0~6 단축키 digit. AppDestination.all 의 shortcutDigit 과 매핑.
  final int digit;
}

class _ShortcutsHost extends StatelessWidget {
  const _ShortcutsHost({
    required this.destinations,
    required this.onSelect,
    required this.child,
  });

  final List<AppDestination> destinations;
  final void Function(int digit) onSelect;
  final Widget child;

  /// 단축키 digit (0~9) ↔ LogicalKeyboardKey 매핑. destinations 의 shortcutDigit
  /// 이 동적이라 매 build 마다 활성 키만 추려서 Shortcuts map 만든다.
  static const _digitKeys = <int, LogicalKeyboardKey>{
    0: LogicalKeyboardKey.digit0,
    1: LogicalKeyboardKey.digit1,
    2: LogicalKeyboardKey.digit2,
    3: LogicalKeyboardKey.digit3,
    4: LogicalKeyboardKey.digit4,
    5: LogicalKeyboardKey.digit5,
    6: LogicalKeyboardKey.digit6,
    7: LogicalKeyboardKey.digit7,
    8: LogicalKeyboardKey.digit8,
    9: LogicalKeyboardKey.digit9,
  };

  @override
  Widget build(BuildContext context) {
    final shortcuts = <ShortcutActivator, Intent>{};
    for (final d in destinations) {
      final digit = d.shortcutDigit;
      if (digit < 0) continue;
      final key = _digitKeys[digit];
      if (key == null) continue;
      shortcuts[SingleActivator(key)] = _SelectDestinationIntent(digit);
    }

    return Shortcuts(
      shortcuts: shortcuts,
      child: Actions(
        actions: <Type, Action<Intent>>{
          _SelectDestinationIntent: _SelectDestinationAction(
            onSelect: onSelect,
          ),
        },
        child: Focus(autofocus: true, child: child),
      ),
    );
  }
}

/// 0~6 키 destination 전환 Action. **TextField focus 시 disabled** 되어 사용자가 todo
/// 제목에 숫자를 입력할 때 의도치 않은 전환이 발생하지 않게 한다.
class _SelectDestinationAction extends Action<_SelectDestinationIntent> {
  _SelectDestinationAction({required this.onSelect});

  final void Function(int digit) onSelect;

  @override
  bool isEnabled(_SelectDestinationIntent intent) => !isFocusInEditableText();

  @override
  Object? invoke(_SelectDestinationIntent intent) {
    onSelect(intent.digit);
    return null;
  }
}

/// primaryFocus 가 [EditableText] (TextField 의 내부) 안에 있는지. 위 Action 의 isEnabled 가
/// 사용. visibleForTesting — 단위 검증 가능.
@visibleForTesting
bool isFocusInEditableText() {
  final focused = FocusManager.instance.primaryFocus;
  final ctx = focused?.context;
  if (ctx == null) return false;
  // EditableText 자기 자신이거나 그 안쪽 (Selection/Toolbar) 일 경우 모두 포착.
  if (ctx.widget is EditableText) return true;
  return ctx.findAncestorWidgetOfExactType<EditableText>() != null;
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<AppDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      width: 220,
      child: ColoredBox(
        color: colorScheme.surfaceContainerHighest,
        child: SafeArea(
          right: false,
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: AppTokens.space12),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTokens.space20,
                  AppTokens.space8,
                  AppTokens.space20,
                  AppTokens.space16,
                ),
                child: Text(
                  'Solo Todo',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              for (var i = 0; i < destinations.length; i++)
                SidebarItem(
                  destination: destinations[i],
                  selected: i == selectedIndex,
                  onTap: () => onSelect(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class SidebarItem extends StatefulWidget {
  @visibleForTesting
  const SidebarItem({
    super.key,
    required this.destination,
    required this.selected,
    required this.onTap,
    this.autofocus = false,
  });

  final AppDestination destination;
  final bool selected;
  final VoidCallback onTap;

  /// 테스트 결정성 — true 면 mount 직후 InkWell 이 focus 를 잡는다.
  final bool autofocus;

  @override
  State<SidebarItem> createState() => SidebarItemState();
}

class SidebarItemState extends State<SidebarItem> {
  /// 키보드 focus 가 이 item 에 들어와 있는지. true 면 outline ring 표시 — 마우스 사용자
  /// 에게도 영향 X (InkWell.onFocusChange 는 키보드 traversal 에서만 true 가 됨).
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = widget.selected
        ? scheme.onSurface
        : scheme.onSurface.withValues(alpha: 0.78);
    final bg = widget.selected
        ? scheme.primary.withValues(alpha: 0.12)
        : Colors.transparent;

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTokens.radiusM),
      side: _focused
          ? BorderSide(color: scheme.primary, width: 2)
          : BorderSide.none,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space8,
        vertical: AppTokens.space2,
      ),
      child: Tooltip(
        message: widget.destination.tooltipWithShortcut,
        waitDuration: const Duration(milliseconds: 600),
        child: Material(
          color: bg,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            autofocus: widget.autofocus,
            // 키보드 focus 가 들어왔다 나갔다 할 때 outline ring 토글.
            onFocusChange: (f) => setState(() => _focused = f),
            // InkWell 의 기본 focusColor (semi-transparent) 는 따로 outline 을 그리므로 끔.
            focusColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.space12,
                vertical: AppTokens.space8,
              ),
              child: Row(
                children: [
                  Icon(
                    widget.destination.icon,
                    size: 18,
                    color: widget.destination.color,
                  ),
                  const SizedBox(width: AppTokens.space12),
                  Expanded(
                    child: Text(
                      widget.destination.label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: fg,
                        fontWeight: widget.selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MainArea extends StatelessWidget {
  const _MainArea({required this.destination});

  final AppDestination destination;

  @override
  Widget build(BuildContext context) {
    if (destination.isToday) return const HomeScreen();
    if (destination.isOutline) return const OutlineScreen();
    return CategoryView(category: destination.category!);
  }
}
