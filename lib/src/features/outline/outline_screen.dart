import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../domain/category.dart';
import '../../domain/todo.dart';
import '../category/categories_controller.dart';
import '../todo_actions/todo_actions_controller.dart';
import 'tree_providers.dart';

/// 전체 트리 view — 카테고리 root + 자식 트리를 한 화면에 펼침/접힘으로 표시.
///
/// v1.4 (Task D) — 상단 탭 2개로 분리:
///   - **체크리스트**: task 트리만 (note 제외). 카테고리 root + task 자식, 진척률·체크 토글.
///   - **메모**: note 만 카테고리별 섹션으로 평탄 나열 (체크 개념 없음, 정적 표시).
///
/// "메모는 메모별로, 체크리스트는 체크리스트로" — 한 화면에 섞지 않는다.
class OutlineScreen extends ConsumerWidget {
  const OutlineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // v1.2 — 동적 카테고리. loading / error 시 builtin 5종 fallback.
    final categories =
        ref.watch(categoriesProvider).asData?.value ?? Category.builtinSeeds;

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
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
                _ChecklistTab(categories: categories),
                _NotesTab(categories: categories),
              ],
            ),
          ),
        ],
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

/// 체크리스트 탭 — 카테고리별 task root + task 자식 트리. note 는 모두 제외.
/// 펼침/접힘 상태는 이 탭이 자체 보유 (탭 전환해도 유지).
class _ChecklistTab extends StatefulWidget {
  const _ChecklistTab({required this.categories});

  final List<Category> categories;

  @override
  State<_ChecklistTab> createState() => _ChecklistTabState();
}

class _ChecklistTabState extends State<_ChecklistTab>
    with AutomaticKeepAliveClientMixin {
  /// "접힌" 노드 id 모음 — default 가 펼침 상태. id 가 set 에 있으면 접힌 상태.
  /// 카테고리 헤더는 'cat:work' 접두 형식, todo 는 그대로 todo.id.
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              for (final c in widget.categories)
                _OutlineCategory(
                  category: c,
                  collapsed: _collapsed,
                  expanded: _expanded,
                  onToggle: _toggle,
                ),
            ]),
          ),
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

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.space12),
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
          if (isExpanded && roots != null)
            for (final r in roots)
              _OutlineNode(
                node: r,
                depth: 1,
                collapsed: collapsed,
                expanded: expanded,
                onToggle: onToggle,
              ),
        ],
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
      borderRadius: BorderRadius.circular(AppTokens.radiusM),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space8,
          vertical: AppTokens.space8,
        ),
        child: Row(
          children: [
            Icon(
              isExpanded
                  ? Icons.keyboard_arrow_down_rounded
                  : Icons.keyboard_arrow_right_rounded,
              size: 20,
              color: scheme.onSurface.withValues(alpha: 0.65),
            ),
            const SizedBox(width: AppTokens.space4),
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
            if (total > 0)
              _ProgressBadge(done: done, total: total, accent: category.color),
          ],
        ),
      ),
    );
  }
}

class _OutlineNode extends ConsumerWidget {
  const _OutlineNode({
    required this.node,
    required this.depth,
    required this.collapsed,
    required this.expanded,
    required this.onToggle,
  });

  final Todo node;
  final int depth;
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
            padding: EdgeInsets.only(
              left: AppTokens.space8 + (depth * 16.0),
              right: AppTokens.space8,
              top: AppTokens.space4,
              bottom: AppTokens.space4,
            ),
            child: Row(
              children: [
                // chevron 자리 — folder 면 펼침 화살표, leaf 면 동일 공간 (열·정렬 유지).
                SizedBox(
                  width: 20,
                  child: isFolder
                      ? Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_down_rounded
                              : Icons.keyboard_arrow_right_rounded,
                          size: 18,
                          color: scheme.onSurface.withValues(alpha: 0.55),
                        )
                      : null,
                ),
                const SizedBox(width: AppTokens.space4),
                // 체크리스트 탭은 task 만 — 탭하면 체크 토글 (자식 트리 포함).
                InkWell(
                  key: ValueKey('outline-check-${node.id}'),
                  onTap: () => ref.read(todoActionsProvider).toggle(node),
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: const EdgeInsets.all(AppTokens.space4),
                    child: Icon(
                      isDone
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked,
                      size: 16,
                      color: isDone
                          ? node.category.color
                          : scheme.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
                ),
                const SizedBox(width: AppTokens.space4),
                Expanded(
                  child: Text(
                    node.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      decoration: isDone ? TextDecoration.lineThrough : null,
                      color: isDone
                          ? scheme.onSurface.withValues(alpha: 0.45)
                          : null,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (progress != null && progress.taskCount > 0)
                  _ProgressBadge(
                    done: progress.doneCount,
                    total: progress.taskCount,
                    accent: node.category.color,
                  ),
              ],
            ),
          ),
        ),
        if (isExpanded)
          for (final c in children)
            _OutlineNode(
              node: c,
              depth: depth + 1,
              collapsed: collapsed,
              expanded: expanded,
              onToggle: onToggle,
            ),
      ],
    );
  }
}

// ───────────────────────── 메모 탭 (note 평탄 목록) ─────────────────────────

/// 메모 탭 — 카테고리별 섹션으로 note 를 평탄 나열. 체크 개념 없이 정적 표시.
class _NotesTab extends StatelessWidget {
  const _NotesTab({required this.categories});

  final List<Category> categories;

  @override
  Widget build(BuildContext context) {
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
            delegate: SliverChildListDelegate([
              for (final c in categories) _NoteCategorySection(category: c),
            ]),
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

/// `[done/total]` 라벨 + 얇은 progress bar. note 는 카운트에서 이미 제외됨.
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
    final ratio = total == 0 ? 0.0 : done / total;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 64),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$done/$total',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: accent,
            ),
          ),
          const SizedBox(height: AppTokens.space2),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTokens.radiusFull),
            child: SizedBox(
              width: 56,
              height: 3,
              child: LinearProgressIndicator(
                value: ratio,
                backgroundColor: accent.withValues(alpha: 0.18),
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
