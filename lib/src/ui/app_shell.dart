import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

import '../core/platform.dart';
import '../core/theme.dart';
import '../data/remote/supabase_realtime_sync.dart';
import '../domain/category.dart';
import '../features/add_todo/add_todo_controller.dart';
import '../features/add_todo/add_todo_sheet.dart';
import '../features/auth/auth_providers.dart';
import '../features/category/category_view.dart';
import '../features/home/home_screen.dart';
import '../features/home/today_providers.dart';
import '../features/system/tray_service.dart';
import 'destination.dart';

/// 폼팩터 분기 컨테이너 + FAB (빠른 추가 트리거) + 1~5 카테고리 단축키.
///
/// 단축키: `0` = Today, `1` = work, `2` = personalDev, `3` = daily, `4` = longterm, `5` = idea.
/// macOS 데스크탑 global Cmd+N 은 phase 6 의 hotkey_manager task 에서 연결.
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
      onQuit: () => SystemNavigator.pop(),
    );
    await tray.init();
    if (!mounted) {
      await tray.dispose();
      return;
    }
    _tray = tray;
  }

  Future<void> _registerGlobalHotkey() async {
    if (!AppPlatform.isDesktop) return;
    try {
      await hotKeyManager.unregisterAll();
      final hotkey = HotKey(
        key: PhysicalKeyboardKey.keyN,
        modifiers: const [HotKeyModifier.meta],
        scope: HotKeyScope.system,
      );
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

  void _select(int i) {
    setState(() => _index = i);
  }

  /// 단축키 → category null (Today) 또는 특정 [Category] 를 받아 destination index 로 매핑.
  void _selectByDestination({Category? category}) {
    final idx = AppDestination.all.indexWhere((d) => d.category == category);
    if (idx >= 0 && idx != _index) _select(idx);
  }

  Future<void> _openAddTodo() async {
    final dest = AppDestination.all[_index];
    final initialCategory = dest.category ?? Category.daily;
    await AddTodoSheet.show(
      context,
      initialCategory: initialCategory,
      onSubmit: (submission) {
        ref.read(addTodoControllerProvider).add(submission);
      },
    );
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

    final destination = AppDestination.all[_index];

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
          _Sidebar(selectedIndex: _index, onSelect: _select),
          const VerticalDivider(width: AppTokens.hairline),
          Expanded(child: _MainArea(destination: destination)),
        ],
      );
    } else {
      body = SafeArea(child: _MainArea(destination: destination));
    }

    return _ShortcutsHost(
      onSelect: _selectByDestination,
      child: Scaffold(
        floatingActionButton: fab,
        // 모바일은 NavigationBar 위에 자연스럽게 정렬되는 endContained — 6 destination 라벨과
        // FAB 가 겹치지 않음. desktop 은 NavigationBar 자체가 없어 기본 endFloat.
        floatingActionButtonLocation: AppPlatform.isDesktop
            ? FloatingActionButtonLocation.endFloat
            : FloatingActionButtonLocation.endContained,
        body: body,
        bottomNavigationBar: AppPlatform.isDesktop
            ? null
            : NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: _select,
                destinations: [
                  for (final d in AppDestination.all)
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
  const _SelectDestinationIntent(this.category);

  /// null 이면 Today.
  final Category? category;
}

class _ShortcutsHost extends StatelessWidget {
  const _ShortcutsHost({required this.onSelect, required this.child});

  final void Function({Category? category}) onSelect;
  final Widget child;

  static final _digitKeys = <LogicalKeyboardKey, Category?>{
    LogicalKeyboardKey.digit0: null,
    LogicalKeyboardKey.digit1: Category.work,
    LogicalKeyboardKey.digit2: Category.personalDev,
    LogicalKeyboardKey.digit3: Category.daily,
    LogicalKeyboardKey.digit4: Category.longterm,
    LogicalKeyboardKey.digit5: Category.idea,
  };

  @override
  Widget build(BuildContext context) {
    final shortcuts = <ShortcutActivator, Intent>{};
    for (final entry in _digitKeys.entries) {
      shortcuts[SingleActivator(entry.key)] = _SelectDestinationIntent(
        entry.value,
      );
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

/// 0~5 키 카테고리 전환 Action. **TextField focus 시 disabled** 되어 사용자가 todo 제목에
/// 숫자를 입력할 때 의도치 않은 카테고리 전환이 발생하지 않게 한다.
class _SelectDestinationAction extends Action<_SelectDestinationIntent> {
  _SelectDestinationAction({required this.onSelect});

  final void Function({Category? category}) onSelect;

  @override
  bool isEnabled(_SelectDestinationIntent intent) => !isFocusInEditableText();

  @override
  Object? invoke(_SelectDestinationIntent intent) {
    onSelect(category: intent.category);
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
  const _Sidebar({required this.selectedIndex, required this.onSelect});

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
              for (var i = 0; i < AppDestination.all.length; i++)
                _SidebarItem(
                  destination: AppDestination.all[i],
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

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final AppDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = selected
        ? scheme.onSurface
        : scheme.onSurface.withValues(alpha: 0.78);
    final bg = selected
        ? scheme.primary.withValues(alpha: 0.12)
        : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space8,
        vertical: AppTokens.space2,
      ),
      child: Tooltip(
        message: destination.tooltipWithShortcut,
        waitDuration: const Duration(milliseconds: 600),
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(AppTokens.radiusM),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.space12,
                vertical: AppTokens.space8,
              ),
              child: Row(
                children: [
                  Icon(destination.icon, size: 18, color: destination.color),
                  const SizedBox(width: AppTokens.space12),
                  Expanded(
                    child: Text(
                      destination.label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: fg,
                        fontWeight: selected
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
    return CategoryView(category: destination.category!);
  }
}
