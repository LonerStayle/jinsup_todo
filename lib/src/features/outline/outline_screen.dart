import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../domain/category.dart';
import '../../domain/group.dart';
import '../../domain/todo.dart';
import '../../ui/widgets/empty_state.dart';
import '../category/categories_controller.dart';
import '../category/groups_controller.dart';
import '../todo_actions/todo_actions_controller.dart';
import 'tree_providers.dart';

/// 전체 트리 view — **그룹 → 카테고리 → 태스크** 계층으로 펼침/접힘 표시.
///
/// v1.4 (Task D) — 상단 탭 2개로 분리:
///   - **체크리스트**: task 트리만 (note 제외). 그룹 헤더 → 카테고리 root + task 자식.
///   - **메모**: note 만 그룹 → 카테고리 섹션으로 평탄 나열 (체크 개념 없음).
///
/// 작업 3 (L) — 카테고리만 평면 나열하던 것을 그룹 계층으로 확장. '미분류' 카테고리는
/// 별도 섹션. 그룹/카테고리 모두 sortOrder 순. 그룹이 하나도 없으면 그룹 헤더 없이
/// 카테고리만 (기존 평면 모양과 동일) 표시한다.
class OutlineScreen extends ConsumerWidget {
  const OutlineScreen({super.key, this.group, this.showHeader = true});

  /// non-null = 이 그룹의 카테고리만 평면으로 (그룹 헤더 없이) 보여 준다 (A안 — 그룹별
  /// '전체보기' 탭). null = 전역 (그룹 → 카테고리 계층).
  final Group? group;

  /// 큰 '전체보기' 헤더 표시 여부 (그룹 탭 임베드 시 false, 체크리스트/메모 탭만 노출).
  final bool showHeader;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // v1.2 — 동적 카테고리. loading / error 시 builtin 5종 fallback.
    final allCategories =
        ref.watch(categoriesProvider).asData?.value ?? Category.builtinSeeds;
    // 작업 3 (L) — 그룹 계층. loading / error 시 빈 목록 (= 그룹 헤더 없는 평면).
    final allGroups =
        ref.watch(groupsProvider).asData?.value ?? const <Group>[];

    // 그룹 스코프면 그 그룹 카테고리만 + 그룹 헤더 제거 (groups 를 비워 평면 렌더).
    final categories = group == null
        ? allCategories
        : allCategories.where((c) => c.groupId == group!.id).toList();
    final groups = group == null ? allGroups : const <Group>[];
    final layout = _OutlineLayout.from(categories: categories, groups: groups);

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          if (showHeader)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.space24,
                AppTokens.space32,
                AppTokens.space24,
                AppTokens.space12,
              ),
              child: _Header(),
            ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppTokens.space16),
            child: TabBar(
              key: ValueKey('outline-tabs'),
              tabs: [
                Tab(text: '체크리스트'),
                Tab(text: '메모'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _ChecklistTab(layout: layout),
                _NotesTab(layout: layout),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 작업 3 (L) — 그룹 → 카테고리 배치를 한 번 계산해 두 탭이 공유.
///
/// '미분류'(groupId == null) 는 [ungrouped] 로, 그룹별 카테고리는 [sections] 로.
/// 존재하지 않는 그룹에 매인 카테고리는 미분류로 흡수한다. 카테고리는 입력
/// (categoriesProvider) 이 이미 sortOrder 순이므로 그 순서를 보존한다. 그룹도 입력
/// (groupsProvider) 의 sortOrder 순.
class _OutlineLayout {
  const _OutlineLayout({
    required this.groups,
    required this.ungrouped,
    required this.byGroup,
  });

  /// 그룹 헤더를 그릴지 여부 — 그룹이 하나라도 있으면 true.
  final List<Group> groups;

  /// 미분류 카테고리들 (sortOrder 순).
  final List<Category> ungrouped;

  /// groupId → 그 그룹의 카테고리들 (sortOrder 순).
  final Map<String, List<Category>> byGroup;

  bool get hasGroups => groups.isNotEmpty;

  static _OutlineLayout from({
    required List<Category> categories,
    required List<Group> groups,
  }) {
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
    // 존재하지 않는 그룹에 매인 카테고리는 미분류로 흡수.
    final groupIds = groups.map((g) => g.id).toSet();
    for (final entry in byGroup.entries.toList()) {
      if (!groupIds.contains(entry.key)) {
        ungrouped.addAll(entry.value);
        byGroup.remove(entry.key);
      }
    }
    return _OutlineLayout(
      groups: groups,
      ungrouped: ungrouped,
      byGroup: byGroup,
    );
  }
}

/// 그룹 헤더 (접힘 토글) — 전체보기 공통. 색 dot + label + chevron + 접힘 상태.
class _OutlineGroupHeader extends StatelessWidget {
  const _OutlineGroupHeader({
    required this.group,
    required this.isExpanded,
    required this.onToggle,
  });

  final Group group;
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(
        top: AppTokens.space8,
        bottom: AppTokens.space4,
      ),
      child: InkWell(
        key: ValueKey('outline-group-${group.id}'),
        onTap: onToggle,
        borderRadius: BorderRadius.circular(AppTokens.radiusM),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.space8,
            vertical: AppTokens.space8,
          ),
          child: Row(
            children: [
              // 그룹 색 막대 — 섹션 정체성을 강하게.
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: group.color,
                  borderRadius: BorderRadius.circular(AppTokens.radiusFull),
                ),
              ),
              const SizedBox(width: AppTokens.space12),
              Expanded(
                child: Text(
                  group.label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              AnimatedRotation(
                turns: isExpanded ? 0 : -0.25,
                duration: AppTokens.motionFast,
                child: Icon(
                  Icons.expand_more_rounded,
                  size: 24,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// '미분류' 섹션 라벨 (그룹 헤더보다 약한 시각 강조). 그룹이 있을 때만 노출.
class _OutlineUngroupedLabel extends StatelessWidget {
  const _OutlineUngroupedLabel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      key: const ValueKey('outline-ungrouped-label'),
      padding: const EdgeInsets.fromLTRB(
        AppTokens.space12,
        AppTokens.space12,
        AppTokens.space12,
        AppTokens.space4,
      ),
      child: Text(
        '미분류',
        style: theme.textTheme.labelSmall?.copyWith(
          color: scheme.onSurface.withValues(alpha: 0.55),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '전체보기',
          style: theme.textTheme.displayMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppTokens.space4),
        Text('체크리스트는 트리로, 메모는 메모별로', style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

// ───────────────────────── 체크리스트 탭 (task 트리) ─────────────────────────

/// 체크리스트 탭 — 그룹 → 카테고리 task root + task 자식 트리. note 는 모두 제외.
/// 펼침/접힘 상태는 이 탭이 자체 보유 (탭 전환해도 유지).
class _ChecklistTab extends ConsumerStatefulWidget {
  const _ChecklistTab({required this.layout});

  final _OutlineLayout layout;

  @override
  ConsumerState<_ChecklistTab> createState() => _ChecklistTabState();
}

class _ChecklistTabState extends ConsumerState<_ChecklistTab>
    with AutomaticKeepAliveClientMixin {
  /// "접힌" 노드 id 모음 — default 가 펼침 상태. id 가 set 에 있으면 접힌 상태.
  /// 그룹 헤더는 `grp:<id>`, 카테고리 헤더는 `cat:work`, todo 는 그대로 todo.id.
  final Set<String> _collapsed = {};

  bool _expanded(String id) => !_collapsed.contains(id);
  void _toggle(String id) {
    setState(() {
      if (_collapsed.contains(id)) {
        _collapsed.remove(id);
      } else {
        _collapsed.add(id);
      }
    });
  }

  @override
  bool get wantKeepAlive => true;

  /// 한 카테고리 트리 위젯 (그룹 안/미분류 공통).
  Widget _category(Category c) => _OutlineCategory(
    category: c,
    collapsed: _collapsed,
    expanded: _expanded,
    onToggle: _toggle,
  );

  /// 체크리스트(= task root) 가 하나라도 있는 카테고리 id 집합만 통과시킨다.
  /// 메모만 있거나 완전히 빈 카테고리는 체크리스트 탭에서 숨긴다 (사용자 요청).
  /// 그 결과 카테고리가 0개가 된 그룹 헤더 / '미분류' 라벨도 함께 숨겨진다.
  List<Widget> _buildChildren(Set<String> withTaskRoot) {
    final layout = widget.layout;
    final children = <Widget>[];
    // 미분류 — 체크리스트 있는 카테고리만.
    final ungrouped = layout.ungrouped
        .where((c) => withTaskRoot.contains(c.id))
        .toList();
    if (ungrouped.isNotEmpty) {
      if (layout.hasGroups) children.add(const _OutlineUngroupedLabel());
      for (final c in ungrouped) {
        children.add(_category(c));
      }
    }
    // 그룹별 섹션 — 체크리스트 있는 카테고리가 하나라도 있을 때만 헤더 노출.
    for (final g in layout.groups) {
      final items = (layout.byGroup[g.id] ?? const <Category>[])
          .where((c) => withTaskRoot.contains(c.id))
          .toList();
      if (items.isEmpty) continue;
      final groupExpanded = _expanded('grp:${g.id}');
      children.add(
        _OutlineGroupHeader(
          group: g,
          isExpanded: groupExpanded,
          onToggle: () => _toggle('grp:${g.id}'),
        ),
      );
      if (groupExpanded) {
        for (final c in items) {
          children.add(_category(c));
        }
      }
    }
    return children;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // 전체 todos 에서 카테고리별 task root 보유 여부를 한 번에 계산.
    // (각 카테고리 헤더의 taskRootsOfCategoryProvider 와 같은 의미 — parentId null + task.)
    final allTodos =
        ref.watch(allTodosProvider).asData?.value ?? const <Todo>[];
    final withTaskRoot = <String>{};
    for (final t in allTodos) {
      if (t.type == TodoType.task && t.parentId == null) {
        withTaskRoot.add(t.category.id);
      }
    }

    final children = _buildChildren(withTaskRoot);
    if (children.isEmpty) {
      return const CustomScrollView(
        key: PageStorageKey('outline-checklist'),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.checklist_rounded,
              title: '체크리스트가 없어요',
              subtitle: '할 일을 추가하면 카테고리별로 여기에 모여요.',
            ),
          ),
        ],
      );
    }

    return CustomScrollView(
      key: const PageStorageKey('outline-checklist'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.space16,
            AppTokens.space12,
            AppTokens.space16,
            AppTokens.space48,
          ),
          sliver: SliverList(delegate: SliverChildListDelegate(children)),
        ),
      ],
    );
  }
}

class _OutlineCategory extends ConsumerWidget {
  const _OutlineCategory({
    required this.category,
    required this.collapsed,
    required this.expanded,
    required this.onToggle,
  });

  final Category category;
  final Set<String> collapsed;
  final bool Function(String id) expanded;
  final void Function(String id) onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 체크리스트 탭 — task root 만 (note root 제외).
    final roots = ref
        .watch(taskRootsOfCategoryProvider(category))
        .asData
        ?.value;
    final allTodos = ref.watch(allTodosProvider).asData?.value;
    final isExpanded = expanded('cat:${category.id}');

    // 카테고리 전체 진척률 — root 의 자기 자신 (task 면) + 각 root 의 subtree.
    var done = 0;
    var total = 0;
    if (roots != null && allTodos != null) {
      for (final r in roots) {
        if (r.type == TodoType.task) {
          total++;
          if (r.isDone) done++;
        }
        final p = computeSubtreeProgress(r, allTodos);
        total += p.taskCount;
        done += p.doneCount;
      }
    }

    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.space12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(AppTokens.radiusL),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
            width: AppTokens.hairline,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CategoryRow(
              category: category,
              done: done,
              total: total,
              isExpanded: isExpanded,
              onTap: () => onToggle('cat:${category.id}'),
            ),
            if (isExpanded && roots != null && roots.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTokens.space12,
                  0,
                  AppTokens.space8,
                  AppTokens.space8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final r in roots)
                      _OutlineNode(
                        node: r,
                        collapsed: collapsed,
                        expanded: expanded,
                        onToggle: onToggle,
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.done,
    required this.total,
    required this.isExpanded,
    required this.onTap,
  });

  final Category category;
  final int done;
  final int total;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      key: ValueKey('outline-category-${category.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.radiusL),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space12),
        child: Row(
          children: [
            // 카테고리 정체성 — 색 타일 + 아이콘 (가독성·스캔성 강화).
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: category.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppTokens.radiusM),
              ),
              child: Icon(category.icon, size: 21, color: category.color),
            ),
            const SizedBox(width: AppTokens.space12),
            Expanded(
              child: Text(
                category.label,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
              ),
            ),
            if (total > 0) ...[
              _ProgressBadge(done: done, total: total, accent: category.color),
              const SizedBox(width: AppTokens.space8),
            ],
            AnimatedRotation(
              turns: isExpanded ? 0 : -0.25,
              duration: AppTokens.motionFast,
              child: Icon(
                Icons.expand_more_rounded,
                size: 24,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutlineNode extends ConsumerWidget {
  const _OutlineNode({
    required this.node,
    required this.collapsed,
    required this.expanded,
    required this.onToggle,
  });

  final Todo node;
  final Set<String> collapsed;
  final bool Function(String id) expanded;
  final void Function(String id) onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 체크리스트 탭 — task 자식만 (note 자식 제외).
    final children = ref.watch(childTasksOfProvider(node.id)).asData?.value;
    final allTodos = ref.watch(allTodosProvider).asData?.value;
    final isFolder = children != null && children.isNotEmpty;
    final isExpanded = isFolder && expanded(node.id);
    final progress = isFolder && allTodos != null
        ? computeSubtreeProgress(node, allTodos)
        : null;

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDone = node.isDone;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          key: ValueKey('outline-node-${node.id}'),
          onTap: isFolder ? () => onToggle(node.id) : null,
          borderRadius: BorderRadius.circular(AppTokens.radiusM),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.space4,
              vertical: AppTokens.space2,
            ),
            child: Row(
              children: [
                // 큰 원형 체크박스 — 명확한 탭 타깃 + 상태 가시성.
                _CheckCircle(
                  checkKey: ValueKey('outline-check-${node.id}'),
                  done: isDone,
                  color: node.category.color,
                  onTap: () => ref.read(todoActionsProvider).toggle(node),
                ),
                const SizedBox(width: AppTokens.space12),
                Expanded(
                  child: Text(
                    node.title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      height: 1.3,
                      fontWeight: isFolder ? FontWeight.w600 : FontWeight.w500,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                      color: isDone
                          ? scheme.onSurface.withValues(alpha: 0.4)
                          : scheme.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (progress != null && progress.taskCount > 0) ...[
                  const SizedBox(width: AppTokens.space8),
                  _ProgressBadge(
                    done: progress.doneCount,
                    total: progress.taskCount,
                    accent: node.category.color,
                  ),
                ],
                // folder 펼침 화살표 — 우측에 두어 체크박스/제목 정렬을 깨지 않는다.
                if (isFolder)
                  Padding(
                    padding: const EdgeInsets.only(left: AppTokens.space4),
                    child: AnimatedRotation(
                      turns: isExpanded ? 0 : -0.25,
                      duration: AppTokens.motionFast,
                      child: Icon(
                        Icons.expand_more_rounded,
                        size: 22,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        // 자식 — 카테고리 색 가이드 레일로 깊이를 시각화 (트리 연결선).
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: AppTokens.space16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: node.category.color.withValues(alpha: 0.28),
                    width: 2,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.only(left: AppTokens.space8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final c in children)
                      _OutlineNode(
                        node: c,
                        collapsed: collapsed,
                        expanded: expanded,
                        onToggle: onToggle,
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 큰 원형 체크박스 — 미완료는 외곽선, 완료는 카테고리 색 채움 + 흰 체크.
/// [checkKey] 는 InkWell 에 부여되어 테스트/탭 타깃 식별에 쓰인다.
class _CheckCircle extends StatelessWidget {
  const _CheckCircle({
    required this.checkKey,
    required this.done,
    required this.color,
    required this.onTap,
  });

  final Key checkKey;
  final bool done;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      key: checkKey,
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space4),
        child: AnimatedContainer(
          duration: AppTokens.motionFast,
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? color : Colors.transparent,
            border: Border.all(color: done ? color : scheme.outline, width: 2),
          ),
          child: done
              ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}

// ───────────────────────── 메모 탭 (note 평탄 목록) ─────────────────────────

/// 메모 탭 — 그룹 → 카테고리 섹션으로 note 를 평탄 나열. 체크 개념 없이 정적 표시.
///
/// 작업 3 (L) — 체크리스트 탭과 일관되게 그룹 헤더(접힘) + '미분류' 섹션 구조.
/// note 가 0건인 카테고리 섹션은 [_NoteCategorySection] 이 스스로 hide 한다.
class _NotesTab extends StatefulWidget {
  const _NotesTab({required this.layout});

  final _OutlineLayout layout;

  @override
  State<_NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<_NotesTab>
    with AutomaticKeepAliveClientMixin {
  final Set<String> _collapsedGroups = {};

  bool _expanded(String groupId) => !_collapsedGroups.contains(groupId);
  void _toggle(String groupId) {
    setState(() {
      if (!_collapsedGroups.remove(groupId)) _collapsedGroups.add(groupId);
    });
  }

  @override
  bool get wantKeepAlive => true;

  List<Widget> _buildChildren() {
    final layout = widget.layout;
    final children = <Widget>[];
    if (layout.ungrouped.isNotEmpty) {
      if (layout.hasGroups) children.add(const _OutlineUngroupedLabel());
      for (final c in layout.ungrouped) {
        children.add(_NoteCategorySection(category: c));
      }
    }
    for (final g in layout.groups) {
      final items = layout.byGroup[g.id] ?? const <Category>[];
      final groupExpanded = _expanded(g.id);
      children.add(
        _OutlineGroupHeader(
          group: g,
          isExpanded: groupExpanded,
          onToggle: () => _toggle(g.id),
        ),
      );
      if (groupExpanded) {
        for (final c in items) {
          children.add(_NoteCategorySection(category: c));
        }
      }
    }
    return children;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return CustomScrollView(
      key: const PageStorageKey('outline-notes'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.space16,
            AppTokens.space12,
            AppTokens.space16,
            AppTokens.space48,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate(_buildChildren()),
          ),
        ),
      ],
    );
  }
}

/// 한 카테고리의 note 섹션. note 가 0건이면 통째로 hide (빈 헤더 노이즈 방지).
class _NoteCategorySection extends ConsumerWidget {
  const _NoteCategorySection({required this.category});

  final Category category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(notesOfCategoryProvider(category)).asData?.value;
    if (notes == null || notes.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Padding(
      key: ValueKey('outline-note-section-${category.id}'),
      padding: const EdgeInsets.only(bottom: AppTokens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.space8,
              vertical: AppTokens.space8,
            ),
            child: Row(
              children: [
                Icon(category.icon, size: 18, color: category.color),
                const SizedBox(width: AppTokens.space8),
                Expanded(
                  child: Text(
                    category.label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${notes.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: category.color,
                  ),
                ),
              ],
            ),
          ),
          for (final n in notes) _NoteCard(note: n),
        ],
      ),
    );
  }
}

/// 단일 메모 카드 — 제목 + (있으면) 본문 미리보기. 체크 토글 없음.
class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note});

  final Todo note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final desc = note.description;
    return Container(
      key: ValueKey('outline-note-${note.id}'),
      margin: const EdgeInsets.symmetric(
        horizontal: AppTokens.space4,
        vertical: AppTokens.space4,
      ),
      padding: const EdgeInsets.all(AppTokens.space12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppTokens.radiusM),
        border: Border(left: BorderSide(color: note.category.color, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.sticky_note_2_outlined,
            size: 16,
            color: scheme.onSurface.withValues(alpha: 0.5),
          ),
          const SizedBox(width: AppTokens.space8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                if (desc != null && desc.trim().isNotEmpty) ...[
                  const SizedBox(height: AppTokens.space4),
                  Text(
                    desc,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// `done/total` 진척 pill. 완료(done==total)면 체크 아이콘 + 진한 배경으로 강조.
/// note 는 카운트에서 이미 제외됨. 텍스트 `$done/$total` 는 그대로 노출(테스트 계약).
class _ProgressBadge extends StatelessWidget {
  const _ProgressBadge({
    required this.done,
    required this.total,
    required this.accent,
  });

  final int done;
  final int total;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final complete = total > 0 && done == total;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space8,
        vertical: AppTokens.space2,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: complete ? 0.20 : 0.11),
        borderRadius: BorderRadius.circular(AppTokens.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (complete) ...[
            Icon(Icons.check_circle_rounded, size: 13, color: accent),
            const SizedBox(width: AppTokens.space4),
          ],
          Text(
            '$done/$total',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}
