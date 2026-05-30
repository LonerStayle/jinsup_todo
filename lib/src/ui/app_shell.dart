import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

import '../core/platform.dart';
import '../core/theme.dart';
import '../data/providers.dart';
import '../data/remote/supabase_realtime_sync.dart';
import '../domain/category.dart';
import '../domain/group.dart';
import '../features/add_todo/add_todo_controller.dart';
import '../features/add_todo/add_todo_sheet.dart';
import '../features/auth/auth_providers.dart';
import '../features/category/add_category_dialog.dart';
import '../features/category/add_group_dialog.dart';
import '../features/category/categories_controller.dart';
import '../features/category/groups_controller.dart';
import '../features/category/category_view.dart';
import '../features/home/home_screen.dart';
import '../features/home/today_providers.dart';
import '../features/manage/manage_drawer.dart';
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

  /// 모바일 Drawer 를 NavigationBar '카테고리' 슬롯에서 열기 위한 키.
  /// (NavigationBar 는 Scaffold 의 형제라 Scaffold.of 로 접근 불가 → key 사용.)
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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

  /// 카테고리 삭제 — confirm dialog 후 controller 호출. blocked 면 안내 dialog.
  /// today / outline destination 은 무시.
  Future<void> _deleteCategory(AppDestination dest) async {
    final category = dest.category;
    if (category == null) return;

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('${category.label} 카테고리 삭제'),
            content: const Text('이 카테고리를 정말 삭제할까요? 되돌릴 수 없어요.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                ),
                child: const Text('삭제'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    final result = await ref
        .read(categoriesControllerProvider)
        .delete(category.id);
    if (!mounted) return;
    if (result.isOk) {
      // _index 가 삭제된 카테고리에 가 있었다면 다음 build 에서 safeIndex 가 today 로
      // fallback. _index 자체도 안전 reset.
      setState(() {
        if (_index >= _destinations.length - 1) _index = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${category.label} 카테고리가 삭제되었어요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // blockedByTodos — 안 todos 가 있어 차단됨. 안내 dialog.
    final count = await ref
        .read(categoriesRepositoryProvider)
        .countTodosOfCategory(category.id);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('삭제할 수 없어요'),
        content: Text(
          '이 카테고리에 할 일이 $count건 있어요. 먼저 다른 카테고리로 옮기거나 todos 부터 삭제해 주세요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  /// 그룹 삭제 — confirm dialog 후 controller 호출. 차단 없음: 속한 카테고리는
  /// '미분류'로 이동되고 그룹만 사라진다 (todos / 카테고리 데이터 무손실).
  Future<void> _deleteGroup(Group group) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text("'${group.label}' 그룹 삭제"),
            content: const Text(
              '그룹을 삭제하면 속한 카테고리는 \'미분류\'로 이동돼요. 카테고리와 할 일은 그대로 남아요.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                ),
                child: const Text('삭제'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    await ref.read(groupsControllerProvider).delete(group.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("'${group.label}' 그룹이 삭제됐어요. 카테고리는 미분류로 이동했어요."),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// 카테고리 '그룹 이동' — 그룹 선택 bottom sheet 후 controller.moveToGroup 호출.
  /// 선택지: 미분류(null) + 현재 그룹들. today / outline 은 무시.
  Future<void> _moveCategoryToGroup(AppDestination dest) async {
    final category = dest.category;
    if (category == null) return;

    final groups = ref.read(groupsProvider).asData?.value ?? const <Group>[];
    final picked = await showModalBottomSheet<_GroupChoice>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.layers_clear_outlined),
              title: const Text('미분류'),
              selected: category.groupId == null,
              onTap: () => Navigator.of(ctx).pop(const _GroupChoice(null)),
            ),
            for (final g in groups)
              ListTile(
                leading: Icon(Icons.circle, size: 14, color: g.color),
                title: Text(g.label),
                selected: category.groupId == g.id,
                onTap: () => Navigator.of(ctx).pop(_GroupChoice(g.id)),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    await ref
        .read(categoriesControllerProvider)
        .moveToGroup(category.id, picked.groupId);
  }

  Future<void> _openAddTodo() async {
    // _index 가 destinations 범위를 벗어났을 수 있으므로 safe lookup.
    final dest = (_index < _destinations.length)
        ? _destinations[_index]
        : _destinations.first;
    // 카테고리 화면이면 그 카테고리. 오늘/전체보기/FAB/Cmd+N 전역 추가는 컨텍스트가
    // 없으므로 **현재 카테고리 목록의 첫 항목**(정렬 기준)을 기본값으로. 무조건 '일상'
    // 으로 떨어지던 버그 (J) 수정 — 목록이 비면 builtinSeeds.first 로 fallback.
    final categories =
        ref.read(categoriesProvider).asData?.value ?? Category.builtinSeeds;
    final fallback = categories.isNotEmpty
        ? categories.first
        : Category.builtinSeeds.first;
    final initialCategory = dest.category ?? fallback;

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

  /// Drawer 에서 카테고리 탭 → 그 카테고리 destination 으로 이동 + Drawer 닫기.
  /// destinations 에서 같은 category id 의 index 를 찾아 _select.
  void _selectCategoryDestination(Category category) {
    final idx = _destinations.indexWhere(
      (d) =>
          d.kind == DestinationKind.category && d.category?.id == category.id,
    );
    if (idx >= 0) _select(idx);
    Navigator.of(context).pop(); // drawer 닫기
  }

  /// 모바일 하단 바 (옵션 1) — `[오늘, 전체보기, 카테고리]` 3 슬롯 고정.
  ///
  /// selectedIndex 는 **가상 인덱스** (destinations 의 실제 index 와 분리):
  ///   - today → 0, outline → 1, 그 외(어느 카테고리든) → 2 (카테고리 슬롯).
  /// 탭:
  ///   - 0 → today destination 으로 _select
  ///   - 1 → outline destination 으로 _select
  ///   - 2 → 관리 Drawer 열기 (카테고리 선택은 Drawer 안에서)
  /// 카테고리 슬롯 라벨/아이콘은 현재 카테고리에 있으면 그 카테고리, 아니면 기본값.
  Widget _buildMobileNavBar(AppDestination current) {
    final onCategory = current.kind == DestinationKind.category;
    final navSelected = current.isToday
        ? 0
        : current.isOutline
        ? 1
        : 2;

    final todayDest = _destinations.firstWhere((d) => d.isToday);
    final outlineDest = _destinations.firstWhere((d) => d.isOutline);

    final categoryIcon = onCategory ? current.icon : Icons.category_outlined;
    final categoryLabel = onCategory ? current.label : '카테고리';

    return NavigationBar(
      selectedIndex: navSelected,
      onDestinationSelected: (i) {
        switch (i) {
          case 0:
            _selectByDestination(todayDest);
            break;
          case 1:
            _selectByDestination(outlineDest);
            break;
          case 2:
            _scaffoldKey.currentState?.openDrawer();
            break;
        }
      },
      destinations: [
        NavigationDestination(icon: Icon(todayDest.icon), label: '오늘'),
        NavigationDestination(icon: Icon(outlineDest.icon), label: '전체보기'),
        NavigationDestination(icon: Icon(categoryIcon), label: categoryLabel),
      ],
    );
  }

  /// destination 객체 → 그 index 로 _select.
  void _selectByDestination(AppDestination dest) {
    final idx = _destinations.indexOf(dest);
    if (idx >= 0) _select(idx);
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

    // v1.3 — 그룹 stream. 사이드바가 그룹 헤더 + 미분류 섹션으로 카테고리를 묶는다.
    final groups = ref.watch(groupsProvider).asData?.value ?? const <Group>[];

    // _index 가 destinations.length 초과 (카테고리 삭제 직후 등) 면 Today (0) 으로 안전 fallback.
    final safeIndex = _index < _destinations.length ? _index : 0;
    final destination = _destinations[safeIndex];

    // 모바일은 NavigationBar 를 가리지 않도록 컴팩트한 원형 FAB (endFloat 가 바 위로 띄움).
    // 데스크탑은 nav bar 가 없어 넓은 extended FAB 유지.
    final fab = AppPlatform.isDesktop
        ? FloatingActionButton.extended(
            key: const ValueKey('add-todo-fab'),
            onPressed: _openAddTodo,
            icon: const Icon(Icons.add),
            label: const Text('추가'),
            tooltip: '새 할 일 (Cmd+N)',
          )
        : FloatingActionButton(
            key: const ValueKey('add-todo-fab'),
            onPressed: _openAddTodo,
            tooltip: '새 할 일',
            child: const Icon(Icons.add),
          );

    final Widget body;
    if (AppPlatform.isDesktop) {
      body = Row(
        children: [
          _Sidebar(
            destinations: _destinations,
            groups: groups,
            selectedIndex: safeIndex,
            onSelect: _select,
            onAddCategory: () => AddCategoryDialog.show(context),
            onAddGroup: () => AddGroupDialog.show(context),
            onDeleteCategory: _deleteCategory,
            onMoveCategory: _moveCategoryToGroup,
            onDeleteGroup: _deleteGroup,
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
        key: _scaffoldKey,
        // 모바일만 상단 앱바 — ☰ 로 그룹/카테고리 관리 Drawer 를 연다 (Task A).
        // 데스크탑은 좌측 _Sidebar 가 모든 관리/네비를 담당하므로 앱바 없음.
        appBar: AppPlatform.isDesktop
            ? null
            : AppBar(
                title: Text(destination.label),
                leading: Builder(
                  builder: (ctx) => IconButton(
                    key: const ValueKey('manage-drawer-button'),
                    icon: const Icon(Icons.menu),
                    tooltip: '그룹/카테고리 관리',
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                  ),
                ),
              ),
        drawer: AppPlatform.isDesktop
            ? null
            : ManageDrawer(onSelectCategory: _selectCategoryDestination),
        floatingActionButton: fab,
        // endFloat — Scaffold 가 FAB 를 bottomNavigationBar **위로** 띄워 네비를 가리지 않음.
        // (이전 endContained 는 nav bar 에 도킹돼 6개 destination 항목을 덮는 문제가 있었다.)
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        body: body,
        // desktop 은 좌측 _Sidebar 가 네비게이션을 담당해 bottomNavigationBar 가 의도적으로
        // null. mobile 만 NavigationBar 노출 — 오늘/전체보기/카테고리 3 슬롯 고정 (옵션 1).
        bottomNavigationBar: AppPlatform.isDesktop
            ? null
            : _buildMobileNavBar(destination),
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

/// 사이드바의 카테고리 그룹 선택 결과 (미분류 = null).
class _GroupChoice {
  const _GroupChoice(this.groupId);
  final String? groupId;
}

/// v1.3 — 데스크탑 사이드바. 그룹 헤더(접힘 가능) → 그 그룹의 카테고리 + 최상단
/// '미분류' 섹션 (groupId == null 카테고리). Today / Outline / 단축키 매핑은
/// [destinations] 의 index 를 그대로 사용 — 시각적 재배치일 뿐 selection 인덱싱은
/// 보존된다.
class _Sidebar extends StatefulWidget {
  const _Sidebar({
    required this.destinations,
    required this.groups,
    required this.selectedIndex,
    required this.onSelect,
    required this.onAddCategory,
    required this.onAddGroup,
    required this.onDeleteCategory,
    required this.onMoveCategory,
    required this.onDeleteGroup,
  });

  final List<AppDestination> destinations;
  final List<Group> groups;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onAddCategory;
  final VoidCallback onAddGroup;
  final ValueChanged<AppDestination> onDeleteCategory;
  final ValueChanged<AppDestination> onMoveCategory;
  final ValueChanged<Group> onDeleteGroup;

  @override
  State<_Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<_Sidebar> {
  /// 접힌 그룹 id 집합. 기본은 모두 펼침.
  final Set<String> _collapsed = <String>{};

  void _toggle(String groupId) {
    setState(() {
      if (!_collapsed.remove(groupId)) _collapsed.add(groupId);
    });
  }

  /// destination index → SidebarItem 위젯. 카테고리만 삭제/이동 컨텍스트 메뉴.
  Widget _item(int index) {
    final dest = widget.destinations[index];
    final isCategory = dest.kind == DestinationKind.category;
    return SidebarItem(
      destination: dest,
      selected: index == widget.selectedIndex,
      onTap: () => widget.onSelect(index),
      // 카테고리만 long-press / right-click 으로 컨텍스트 메뉴 (삭제 / 그룹 이동).
      onLongPress: isCategory ? () => _showCategoryMenu(dest) : null,
    );
  }

  /// 카테고리 long-press / 우클릭 메뉴 — 삭제 / 그룹 이동.
  Future<void> _showCategoryMenu(AppDestination dest) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.drive_file_move_outlined),
              title: const Text('그룹 이동'),
              onTap: () => Navigator.of(ctx).pop('move'),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(ctx).colorScheme.error,
              ),
              title: const Text('삭제'),
              onTap: () => Navigator.of(ctx).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'move') {
      widget.onMoveCategory(dest);
    } else if (action == 'delete') {
      widget.onDeleteCategory(dest);
    }
  }

  /// 그룹 헤더 long-press / 우클릭 메뉴 — 삭제. (그룹 삭제 시 속한 카테고리는
  /// '미분류'로 이동되며 차단되지 않는다 — repo deleteById 의 detach 로직.)
  Future<void> _showGroupMenu(Group group) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(ctx).colorScheme.error,
              ),
              title: Text("'${group.label}' 그룹 삭제"),
              onTap: () => Navigator.of(ctx).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'delete') {
      widget.onDeleteGroup(group);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // 카테고리 destination 들을 groupId 별로 분류 (index 보존).
    final ungrouped = <int>[];
    final byGroup = <String, List<int>>{};
    int? outlineIndex;
    int? todayIndex;
    for (var i = 0; i < widget.destinations.length; i++) {
      final d = widget.destinations[i];
      switch (d.kind) {
        case DestinationKind.today:
          todayIndex = i;
          break;
        case DestinationKind.outline:
          outlineIndex = i;
          break;
        case DestinationKind.category:
          final gid = d.category?.groupId;
          if (gid == null) {
            ungrouped.add(i);
          } else {
            byGroup.putIfAbsent(gid, () => <int>[]).add(i);
          }
          break;
      }
    }

    final children = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.space20,
          AppTokens.space8,
          AppTokens.space20,
          AppTokens.space16,
        ),
        child: Text(
          'Solo Todo',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      if (todayIndex != null) _item(todayIndex),
      // v1.4 (Task G) — 전체보기를 '오늘' 바로 다음으로 (카테고리/그룹 섹션 앞).
      if (outlineIndex != null) _item(outlineIndex),
      // 미분류 섹션 — groupId == null 카테고리. 그룹이 하나라도 있을 때만 헤더 라벨.
      if (ungrouped.isNotEmpty) ...[
        if (widget.groups.isNotEmpty)
          _SectionLabel(label: '미분류', textTheme: textTheme),
        for (final i in ungrouped) _item(i),
      ],
      // 그룹별 섹션 — 헤더(접힘 토글) + 그 그룹의 카테고리.
      for (final g in widget.groups) ...[
        _GroupHeader(
          group: g,
          collapsed: _collapsed.contains(g.id),
          onTap: () => _toggle(g.id),
          onLongPress: () => _showGroupMenu(g),
        ),
        if (!_collapsed.contains(g.id))
          for (final i in (byGroup[g.id] ?? const <int>[])) _item(i),
      ],
      // v1.2 — 카테고리 추가 / v1.3 — 그룹 추가 버튼.
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.space12,
          AppTokens.space8,
          AppTokens.space12,
          AppTokens.space4,
        ),
        child: TextButton.icon(
          key: const ValueKey('sidebar-add-category'),
          onPressed: widget.onAddCategory,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('카테고리 추가'),
          style: TextButton.styleFrom(
            foregroundColor: colorScheme.onSurface.withValues(alpha: 0.72),
            alignment: Alignment.centerLeft,
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.space12,
          AppTokens.space2,
          AppTokens.space12,
          AppTokens.space12,
        ),
        child: TextButton.icon(
          key: const ValueKey('sidebar-add-group'),
          onPressed: widget.onAddGroup,
          icon: const Icon(Icons.create_new_folder_outlined, size: 18),
          label: const Text('그룹 추가'),
          style: TextButton.styleFrom(
            foregroundColor: colorScheme.onSurface.withValues(alpha: 0.72),
            alignment: Alignment.centerLeft,
          ),
        ),
      ),
    ];

    return SizedBox(
      width: 220,
      child: ColoredBox(
        color: colorScheme.surfaceContainerHighest,
        child: SafeArea(
          right: false,
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: AppTokens.space12),
            children: children,
          ),
        ),
      ),
    );
  }
}

/// '미분류' 등 섹션 라벨 (그룹 헤더보다 약한 시각 강조).
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.textTheme});

  final String label;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.space20,
        AppTokens.space12,
        AppTokens.space20,
        AppTokens.space4,
      ),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// 그룹 헤더 — 색 dot + label + 접힘 chevron. tap 으로 접힘 토글.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.group,
    required this.collapsed,
    required this.onTap,
    this.onLongPress,
  });

  final Group group;
  final bool collapsed;
  final VoidCallback onTap;

  /// long-press / 우클릭 — 그룹 컨텍스트 메뉴 (삭제). 카테고리 아이템과 동일 패턴.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.space8,
        AppTokens.space8,
        AppTokens.space8,
        AppTokens.space2,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radiusM),
        onTap: onTap,
        onLongPress: onLongPress,
        onSecondaryTap: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.space12,
            vertical: AppTokens.space8,
          ),
          child: Row(
            children: [
              Icon(Icons.circle, size: 12, color: group.color),
              const SizedBox(width: AppTokens.space8),
              Expanded(
                child: Text(
                  group.label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                collapsed ? Icons.chevron_right : Icons.expand_more,
                size: 18,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
    this.onLongPress,
    this.autofocus = false,
  });

  final AppDestination destination;
  final bool selected;
  final VoidCallback onTap;

  /// long-press / right-click — 카테고리 destination 의 삭제 진입점. null 이면 비활성.
  final VoidCallback? onLongPress;

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
            onLongPress: widget.onLongPress,
            // 데스크탑의 우클릭도 long-press 와 같은 동작 (삭제 진입점).
            onSecondaryTap: widget.onLongPress,
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
