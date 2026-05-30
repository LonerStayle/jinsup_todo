import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../domain/category.dart';
import '../../domain/group.dart';
import '../category/add_category_dialog.dart';
import '../category/add_group_dialog.dart';
import '../category/categories_controller.dart';
import '../category/groups_controller.dart';

/// 모바일 그룹/카테고리 관리 Drawer (Task A).
///
/// 데스크탑 사이드바(`app_shell._Sidebar`)와 동일 기능을 모바일 좁은 폭에서
/// 제공한다 — 그룹 추가/삭제, 카테고리 추가/삭제/그룹이동. 추가로 카테고리를
/// **길게 눌러 다른 그룹 헤더(또는 '미분류') 위로 드롭**하면 그 그룹으로 이동한다
/// (E). 각 카테고리 행은 소속 그룹명/색 chip 을 보여 준다 (F).
///
/// 자가완결 — 삭제/이동 confirm 다이얼로그를 직접 들고 있어 app_shell 의 핸들러를
/// 재주입받을 필요가 없다. 컨트롤러/다이얼로그(`AddCategoryDialog` / `AddGroupDialog`
/// / `categoriesControllerProvider` / `groupsControllerProvider`)는 재사용.
class ManageDrawer extends ConsumerStatefulWidget {
  const ManageDrawer({super.key, this.onSelectCategory, this.onSelectGroup});

  /// 카테고리 행 탭 시 호출 — 그 카테고리 화면으로 이동 + Drawer 닫기 (app_shell 주입).
  /// null 이면 탭은 long-press 메뉴와 동일 동작(이전 호환). 보통은 주입된다.
  final ValueChanged<Category>? onSelectCategory;

  /// A안 — 그룹 헤더 탭 시 호출 — 그 그룹 화면(오늘/전체보기)으로 이동 + Drawer 닫기.
  /// null 이면 헤더 본문 탭이 접힘 토글로 fallback (이전 호환).
  final ValueChanged<Group>? onSelectGroup;

  @override
  ConsumerState<ManageDrawer> createState() => _ManageDrawerState();
}

class _ManageDrawerState extends ConsumerState<ManageDrawer> {
  /// 접힌 그룹 id 집합. 기본은 모두 펼침.
  final Set<String> _collapsed = <String>{};

  /// 드래그 중인 카테고리 위로 hover 중인 drop target group id. '미분류' 는
  /// 센티넬 [_ungroupedTargetKey]. 시각 피드백용.
  Object? _hoverTarget;

  /// '미분류' drop target 의 hover 키 (groupId == null 과 구분).
  static const Object _ungroupedTargetKey = Object();

  void _toggle(String groupId) {
    setState(() {
      if (!_collapsed.remove(groupId)) _collapsed.add(groupId);
    });
  }

  Future<void> _addCategory() => AddCategoryDialog.show(context);
  Future<void> _addGroup() => AddGroupDialog.show(context);

  /// 그룹 이름/색 수정 — 프리필된 다이얼로그(upsert). 같은 id 라 카테고리 소속 유지.
  Future<void> _editGroup(Group group) =>
      AddGroupDialog.showEdit(context, group);

  /// 그룹 헤더 long-press / 우클릭 메뉴 — 이름 수정 / 삭제. 삭제는 confirm 모달 경유.
  Future<void> _showGroupMenu(Group group) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('이름·색 수정'),
              onTap: () => Navigator.of(ctx).pop('edit'),
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
    if (action == 'edit') {
      await _editGroup(group);
    } else if (action == 'delete') {
      await _deleteGroup(group);
    }
  }

  /// 카테고리 삭제 — confirm → controller. blocked(할 일 ≥1) 면 안내 dialog.
  Future<void> _deleteCategory(Category category) async {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${category.label} 카테고리가 삭제되었어요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
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

  /// 그룹 삭제 — confirm → controller. 차단 없음 (속한 카테고리는 미분류로 이동).
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

  /// 카테고리 '그룹 이동' bottom sheet — 미분류(null) + 그룹들 중 택1.
  Future<void> _moveCategory(Category category, List<Group> groups) async {
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
    await _applyMove(category, picked.groupId);
  }

  /// 실제 그룹 이동 호출 + 변동 시 snackbar (drag drop / bottom sheet 공통).
  Future<void> _applyMove(Category category, String? groupId) async {
    if (category.groupId == groupId) return;
    await ref
        .read(categoriesControllerProvider)
        .moveToGroup(category.id, groupId);
  }

  /// 작업 2 (K) — 같은 그룹/미분류 안에서 카테고리 순서 변경 (드래그 핸들).
  Future<void> _reorderInGroup(
    List<Category> siblings,
    int oldIndex,
    int newIndex,
  ) async {
    await ref
        .read(categoriesControllerProvider)
        .reorderInGroup(siblings, oldIndex, newIndex);
  }

  /// 카테고리 long-press 메뉴 — 그룹 이동 / 삭제.
  Future<void> _showCategoryMenu(Category category, List<Group> groups) async {
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
      await _moveCategory(category, groups);
    } else if (action == 'delete') {
      await _deleteCategory(category);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final categories =
        ref.watch(categoriesProvider).asData?.value ?? Category.builtinSeeds;
    final groups = ref.watch(groupsProvider).asData?.value ?? const <Group>[];

    // 카테고리를 groupId 별로 분류.
    final ungrouped = <Category>[];
    final byGroup = <String, List<Category>>{};
    for (final c in categories) {
      final gid = c.groupId;
      if (gid == null) {
        ungrouped.add(c);
      } else {
        byGroup.putIfAbsent(gid, () => <Category>[]).add(c);
      }
    }
    // 미분류 + 존재하는 그룹에 안 잡힌 (orphan group_id) 카테고리도 미분류로.
    final groupIds = groups.map((g) => g.id).toSet();
    for (final entry in byGroup.entries.toList()) {
      if (!groupIds.contains(entry.key)) {
        ungrouped.addAll(entry.value);
        byGroup.remove(entry.key);
      }
    }

    final children = <Widget>[
      // 미분류 섹션 — 그룹이 하나라도 있을 때만 헤더 라벨.
      _UngroupedDropZone(
        hovering: _hoverTarget == _ungroupedTargetKey,
        showLabel: groups.isNotEmpty,
        onWillAccept: () => setState(() => _hoverTarget = _ungroupedTargetKey),
        onLeave: () => setState(() => _hoverTarget = null),
        onAccept: (cat) {
          setState(() => _hoverTarget = null);
          _applyMove(cat, null);
        },
        children: [
          if (ungrouped.isNotEmpty)
            _ReorderableCategoryList(
              siblings: ungrouped,
              group: null,
              onTapCategory: (c) => widget.onSelectCategory?.call(c),
              onMenuCategory: (c) => _showCategoryMenu(c, groups),
              onReorder: (oldI, newI) => _reorderInGroup(ungrouped, oldI, newI),
            ),
          if (ungrouped.isEmpty && groups.isNotEmpty)
            _EmptyHint(text: '여기로 드래그하면 그룹에서 빼요'),
        ],
      ),
      for (final g in groups) ...[
        _GroupDropHeader(
          group: g,
          collapsed: _collapsed.contains(g.id),
          hovering: _hoverTarget == g.id,
          onSelect: () => widget.onSelectGroup != null
              ? widget.onSelectGroup!(g)
              : _toggle(g.id),
          onToggleCollapse: () => _toggle(g.id),
          onLongPress: () => _showGroupMenu(g),
          onWillAccept: () => setState(() => _hoverTarget = g.id),
          onLeave: () => setState(() => _hoverTarget = null),
          onAccept: (cat) {
            setState(() => _hoverTarget = null);
            _applyMove(cat, g.id);
          },
        ),
        if (!_collapsed.contains(g.id))
          _ReorderableCategoryList(
            siblings: byGroup[g.id] ?? const <Category>[],
            group: g,
            onTapCategory: (c) => widget.onSelectCategory?.call(c),
            onMenuCategory: (c) => _showCategoryMenu(c, groups),
            onReorder: (oldI, newI) => _reorderInGroup(
              byGroup[g.id] ?? const <Category>[],
              oldI,
              newI,
            ),
          ),
      ],
      const Divider(height: AppTokens.space24),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.space12),
        child: TextButton.icon(
          key: const ValueKey('drawer-add-category'),
          onPressed: _addCategory,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('카테고리 추가'),
          style: TextButton.styleFrom(
            foregroundColor: scheme.onSurface.withValues(alpha: 0.78),
            alignment: Alignment.centerLeft,
            minimumSize: const Size.fromHeight(44),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.space12),
        child: TextButton.icon(
          key: const ValueKey('drawer-add-group'),
          onPressed: _addGroup,
          icon: const Icon(Icons.create_new_folder_outlined, size: 18),
          label: const Text('그룹 추가'),
          style: TextButton.styleFrom(
            foregroundColor: scheme.onSurface.withValues(alpha: 0.78),
            alignment: Alignment.centerLeft,
            minimumSize: const Size.fromHeight(44),
          ),
        ),
      ),
      const SizedBox(height: AppTokens.space12),
    ];

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.space20,
                AppTokens.space16,
                AppTokens.space20,
                AppTokens.space8,
              ),
              child: Text(
                '관리',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.space20,
                0,
                AppTokens.space20,
                AppTokens.space8,
              ),
              child: Text(
                '카테고리를 길게 눌러 그룹으로 드래그할 수 있어요.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ),
            const Divider(height: AppTokens.hairline),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: AppTokens.space8),
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 그룹 선택 결과 (미분류 = null).
class _GroupChoice {
  const _GroupChoice(this.groupId);
  final String? groupId;
}

/// 작업 2 (K) — 같은 그룹/미분류 안의 카테고리들을 ReorderableListView 로 묶어
/// 드래그 핸들(우측 ⠿)로 순서 변경. 행 본문 long-press 는 기존대로 그룹간 이동
/// (LongPressDraggable) 을 유지해 두 제스처가 충돌하지 않는다.
///
/// 바깥이 스크롤(ListView) 이므로 shrinkWrap + NeverScrollable 로 본 리스트는 자체
/// 스크롤하지 않는다 (1인 사용자 카테고리 수 ~수십 규모로 충분).
class _ReorderableCategoryList extends StatelessWidget {
  const _ReorderableCategoryList({
    required this.siblings,
    required this.group,
    required this.onTapCategory,
    required this.onMenuCategory,
    required this.onReorder,
  });

  final List<Category> siblings;
  final Group? group;
  final ValueChanged<Category> onTapCategory;
  final ValueChanged<Category> onMenuCategory;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: siblings.length,
      onReorder: onReorder,
      proxyDecorator: (child, index, animation) =>
          Material(color: Colors.transparent, child: child),
      itemBuilder: (context, index) {
        final c = siblings[index];
        return _CategoryRow(
          key: ValueKey('manage-cat-${c.id}'),
          category: c,
          group: group,
          reorderIndex: index,
          onTap: () => onTapCategory(c),
          onMenu: () => onMenuCategory(c),
        );
      },
    );
  }
}

/// 카테고리 한 행 — LongPressDraggable(그룹간 이동). 소속 그룹 chip(F) 노출.
/// 우측 ⋮ 는 메뉴(그룹 이동 / 삭제), ⠿ 는 [ReorderableDragStartListener](같은 그룹 안
/// 순서 변경, K).
///
/// **제스처 분리**: long-press 는 `LongPressDraggable`(그룹간 드래그 이동) **전용**.
/// 예전엔 InkWell.onLongPress(메뉴)와 long-press 가 충돌해 드래그가 잘 안 됐다 →
/// 메뉴를 ⋮ 버튼으로 분리해 충돌 제거.
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    super.key,
    required this.category,
    required this.group,
    required this.onTap,
    required this.onMenu,
    required this.reorderIndex,
  });

  final Category category;

  /// 소속 그룹. null = 미분류.
  final Group? group;

  /// 탭 — 그 카테고리 화면으로 이동 + Drawer 닫기.
  final VoidCallback onTap;

  /// ⋮ 버튼 / 우클릭 — 그룹 이동 / 삭제 메뉴.
  final VoidCallback onMenu;

  /// ReorderableListView 안에서의 인덱스 — 드래그 핸들이 사용.
  final int reorderIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final tile = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space12,
        vertical: AppTokens.space2,
      ),
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppTokens.radiusM),
        child: InkWell(
          onTap: onTap,
          // long-press 는 아래 LongPressDraggable(그룹간 이동) 전용 — 여기선 안 잡는다.
          onSecondaryTap: onMenu,
          borderRadius: BorderRadius.circular(AppTokens.radiusM),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.space12,
              vertical: AppTokens.space12,
            ),
            child: Row(
              children: [
                Icon(category.icon, size: 18, color: category.color),
                const SizedBox(width: AppTokens.space12),
                Expanded(
                  child: Text(
                    category.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppTokens.space8),
                _GroupChip(group: group),
                // ⋮ 메뉴 — 그룹 이동 / 삭제. (long-press 는 드래그 전용이라 분리)
                IconButton(
                  onPressed: onMenu,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  tooltip: '메뉴',
                  icon: Icon(
                    Icons.more_vert,
                    size: 18,
                    color: scheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                // 드래그 핸들 — 같은 그룹 안 순서 변경(K). 행 본문 long-press 의
                // 그룹간 이동과 별개 제스처라 충돌하지 않는다.
                ReorderableDragStartListener(
                  index: reorderIndex,
                  child: Icon(
                    Icons.drag_indicator,
                    size: 18,
                    color: scheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return LongPressDraggable<Category>(
      data: category,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: _DragFeedback(category: category),
      childWhenDragging: Opacity(opacity: 0.4, child: tile),
      child: tile,
    );
  }
}

/// 카테고리 소속 그룹 chip (F). 미분류면 약한 라벨.
class _GroupChip extends StatelessWidget {
  const _GroupChip({required this.group});

  final Group? group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final g = group;
    final color = g?.color ?? scheme.onSurface.withValues(alpha: 0.4);
    final label = g?.label ?? '미분류';
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space8,
        vertical: AppTokens.space2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppTokens.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: AppTokens.space4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 72),
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: g != null
                    ? scheme.onSurface.withValues(alpha: 0.8)
                    : scheme.onSurface.withValues(alpha: 0.5),
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// 드래그 중 손가락 아래 떠다니는 피드백 칩.
class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.category});

  final Category category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space12,
          vertical: AppTokens.space8,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppTokens.radiusFull),
          border: Border.all(color: category.color, width: 1.6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(category.icon, size: 16, color: category.color),
            const SizedBox(width: AppTokens.space8),
            Text(
              category.label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 그룹 헤더 — DragTarget. 카테고리를 드롭하면 그 그룹으로 이동(E).
///
/// A안: 본문 탭 = 그룹 화면 진입([onSelect]), 우측 chevron 탭 = 접힘 토글
/// ([onToggleCollapse]).
class _GroupDropHeader extends StatelessWidget {
  const _GroupDropHeader({
    required this.group,
    required this.collapsed,
    required this.hovering,
    required this.onSelect,
    required this.onToggleCollapse,
    required this.onLongPress,
    required this.onWillAccept,
    required this.onLeave,
    required this.onAccept,
  });

  final Group group;
  final bool collapsed;
  final bool hovering;
  final VoidCallback onSelect;
  final VoidCallback onToggleCollapse;
  final VoidCallback onLongPress;
  final VoidCallback onWillAccept;
  final VoidCallback onLeave;
  final ValueChanged<Category> onAccept;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DragTarget<Category>(
      onWillAcceptWithDetails: (details) {
        onWillAccept();
        // 이미 이 그룹이면 거절 (시각만 — accept 는 어차피 no-op 가드).
        return details.data.groupId != group.id;
      },
      onLeave: (_) => onLeave(),
      onAcceptWithDetails: (details) => onAccept(details.data),
      builder: (context, candidate, rejected) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.space8,
            AppTokens.space8,
            AppTokens.space8,
            AppTokens.space2,
          ),
          child: Material(
            color: hovering
                ? group.color.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTokens.radiusM),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTokens.radiusM),
              onTap: onSelect,
              onLongPress: onLongPress,
              onSecondaryTap: onLongPress,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTokens.radiusM),
                  border: hovering
                      ? Border.all(color: group.color, width: 1.6)
                      : null,
                ),
                padding: const EdgeInsets.fromLTRB(
                  AppTokens.space12,
                  AppTokens.space4,
                  AppTokens.space4,
                  AppTokens.space4,
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
                          color: scheme.onSurface.withValues(alpha: 0.85),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        collapsed ? Icons.chevron_right : Icons.expand_more,
                        size: 18,
                      ),
                      color: scheme.onSurface.withValues(alpha: 0.5),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      tooltip: collapsed ? '펼치기' : '접기',
                      onPressed: onToggleCollapse,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 미분류 섹션 — DragTarget(그룹에서 빼기) + 라벨 + 그 안의 카테고리 행들.
class _UngroupedDropZone extends StatelessWidget {
  const _UngroupedDropZone({
    required this.hovering,
    required this.showLabel,
    required this.onWillAccept,
    required this.onLeave,
    required this.onAccept,
    required this.children,
  });

  final bool hovering;
  final bool showLabel;
  final VoidCallback onWillAccept;
  final VoidCallback onLeave;
  final ValueChanged<Category> onAccept;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DragTarget<Category>(
      onWillAcceptWithDetails: (details) {
        onWillAccept();
        return details.data.groupId != null;
      },
      onLeave: (_) => onLeave(),
      onAcceptWithDetails: (details) => onAccept(details.data),
      builder: (context, candidate, rejected) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: AppTokens.space4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.radiusM),
            color: hovering
                ? scheme.primary.withValues(alpha: 0.08)
                : Colors.transparent,
            border: hovering
                ? Border.all(color: scheme.primary, width: 1.4)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showLabel)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTokens.space16,
                    AppTokens.space12,
                    AppTokens.space16,
                    AppTokens.space4,
                  ),
                  child: Text(
                    '미분류',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ...children,
            ],
          ),
        );
      },
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space16,
        vertical: AppTokens.space8,
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
