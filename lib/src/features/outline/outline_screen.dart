import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../domain/category.dart';
import '../../domain/todo.dart';
import '../category/categories_controller.dart';
import 'tree_providers.dart';

/// 전체 트리 view — 5 카테고리 root + 자식 트리를 한 화면에 펼침/접힘으로 표시.
///
/// 메모장 가독성에 가까운 outline UI. 각 폴더 헤더는 `[done/task]` + progress bar 로
/// 서브트리 진척률 표시 (note 는 분모 제외). 깊이별 16px 들여쓰기.
class OutlineScreen extends ConsumerStatefulWidget {
  const OutlineScreen({super.key});

  @override
  ConsumerState<OutlineScreen> createState() => _OutlineScreenState();
}

class _OutlineScreenState extends ConsumerState<OutlineScreen> {
  /// "접힌" 노드 id 모음 — default 가 펼침 상태. id 가 set 에 있으면 접힌 상태.
  /// 카테고리 헤더는 'cat:work' 같은 접두 형식으로 구분, todo 는 그대로 todo.id.
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
  Widget build(BuildContext context) {
    // v1.2 — 동적 카테고리. loading / error 시 builtin 5종 fallback.
    final categories =
        ref.watch(categoriesProvider).asData?.value ?? Category.builtinSeeds;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.space24,
            AppTokens.space32,
            AppTokens.space24,
            AppTokens.space16,
          ),
          sliver: SliverToBoxAdapter(child: _Header()),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.space16,
            0,
            AppTokens.space16,
            AppTokens.space48,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              for (final c in categories)
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
        Text('카테고리 / 폴더 / 메모를 한 화면에', style: theme.textTheme.bodyMedium),
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
    final roots = ref.watch(rootsOfCategoryProvider(category)).asData?.value;
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
    final children = ref.watch(childrenOfProvider(node.id)).asData?.value;
    final allTodos = ref.watch(allTodosProvider).asData?.value;
    final isFolder = children != null && children.isNotEmpty;
    final isExpanded = isFolder && expanded(node.id);
    final progress = isFolder && allTodos != null
        ? computeSubtreeProgress(node, allTodos)
        : null;

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isNote = node.type == TodoType.note;
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
                Icon(
                  isNote
                      ? Icons.sticky_note_2_outlined
                      : (isDone
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked),
                  size: 16,
                  color: isNote
                      ? scheme.onSurface.withValues(alpha: 0.45)
                      : (isDone
                            ? node.category.color
                            : scheme.onSurface.withValues(alpha: 0.45)),
                ),
                const SizedBox(width: AppTokens.space8),
                Expanded(
                  child: Text(
                    node.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      decoration: isDone ? TextDecoration.lineThrough : null,
                      color: isDone
                          ? scheme.onSurface.withValues(alpha: 0.45)
                          : null,
                      fontStyle: isNote ? FontStyle.italic : null,
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
