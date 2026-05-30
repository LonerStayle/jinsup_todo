import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../domain/category.dart';
import '../../domain/todo.dart';
import '../../ui/widgets/empty_state.dart';
import '../../ui/widgets/nested_todo_tree.dart';
import '../../ui/widgets/skeleton.dart';
import '../../ui/widgets/undo_snackbar.dart';
import '../add_todo/add_todo_controller.dart';
import '../add_todo/add_todo_sheet.dart';
import '../todo_actions/todo_actions_controller.dart';
import 'category_providers.dart';

/// 카테고리 destination 선택 시 보여줄 화면. 헤더 + 미체크/완료 통계 + 리스트.
class CategoryView extends ConsumerWidget {
  const CategoryView({super.key, required this.category});

  final Category category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTodos = ref.watch(watchTodosByCategoryProvider(category));

    return asyncTodos.when(
      loading: () => const TodoListSkeleton(),
      error: (e, _) => _Error(message: '$e'),
      data: (todos) => _Loaded(
        category: category,
        todos: todos,
        onToggle: (t) => ref.read(todoActionsProvider).toggle(t),
        onDelete: (t) async {
          final actions = ref.read(todoActionsProvider);
          await actions.delete(t);
          if (!context.mounted) return;
          showUndoSnackbar(
            context,
            message: '"${t.title}" 삭제됨',
            onUndo: () => actions.restore(t),
          );
        },
        onTap: (t) async {
          await AddTodoSheet.show(
            context,
            initialCategory: t.category,
            initialTodo: t,
            onSubmit: (_) {},
            onUpdate: (updated) =>
                ref.read(todoActionsProvider).update(updated),
          );
        },
        onAddChild: (parent) => showAddChildSheet(context, ref, parent: parent),
        onReorderSiblings: (siblings, oldIndex, newIndex) => ref
            .read(todoActionsProvider)
            .reorderSiblings(siblings, oldIndex, newIndex),
      ),
    );
  }
}

class _Loaded extends StatefulWidget {
  const _Loaded({
    required this.category,
    required this.todos,
    required this.onToggle,
    required this.onDelete,
    required this.onTap,
    required this.onAddChild,
    required this.onReorderSiblings,
  });

  final Category category;

  /// 이 카테고리에 속한 모든 todo (root + 자손). root + child 인덱스 양쪽에 사용.
  final List<Todo> todos;
  final void Function(Todo) onToggle;
  final void Function(Todo) onDelete;
  final void Function(Todo) onTap;
  final void Function(Todo) onAddChild;
  final void Function(List<Todo> siblings, int oldIndex, int newIndex)
  onReorderSiblings;

  @override
  State<_Loaded> createState() => _LoadedState();
}

class _LoadedState extends State<_Loaded> {
  final Set<String> _collapsed = {};

  void _toggleCollapse(String id) {
    setState(() {
      if (!_collapsed.remove(id)) _collapsed.add(id);
    });
  }

  /// 이 카테고리의 root (parentId null). 자식은 트리에서 들여쓰기로 표시.
  List<Todo> get _roots =>
      widget.todos.where((t) => t.parentId == null).toList();

  @override
  Widget build(BuildContext context) {
    final todos = widget.todos;
    final category = widget.category;
    // 미체크/완료 카운트는 **task 만** 센다. note(메모) 는 체크 개념이 없어
    // isDone 이 항상 false → 예전엔 모두 '미체크'로 잘못 잡혔다 (이슈 수정).
    final tasks = todos.where((t) => t.type == TodoType.task);
    final undone = tasks.where((t) => !t.isDone).length;
    final done = tasks.where((t) => t.isDone).length;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.space24,
            AppTokens.space32,
            AppTokens.space24,
            AppTokens.space16,
          ),
          sliver: SliverToBoxAdapter(
            child: _Header(category: category, undone: undone, done: done),
          ),
        ),
        if (todos.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: category.icon,
              tone: category.color,
              title: '${category.label}에 할 일이 없어요',
              subtitle: '여기에 추가하면 ${category.label} 카테고리로 분류됩니다.',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.space24,
              AppTokens.space8,
              AppTokens.space24,
              AppTokens.space48,
            ),
            sliver: NestedTodoTreeSliver(
              roots: _roots,
              allTodos: todos,
              collapsed: _collapsed,
              onToggleCollapse: _toggleCollapse,
              onToggle: widget.onToggle,
              onDelete: widget.onDelete,
              onTap: widget.onTap,
              onAddChild: widget.onAddChild,
              onReorderSiblings: widget.onReorderSiblings,
            ),
          ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.category,
    required this.undone,
    required this.done,
  });

  final Category category;
  final int undone;
  final int done;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: category.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppTokens.radiusM),
              ),
              child: Icon(category.icon, color: category.color),
            ),
            const SizedBox(width: AppTokens.space12),
            Expanded(
              child: Text(
                category.label,
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTokens.space12),
        Row(
          children: [
            _StatChip(label: '미체크', count: undone, color: category.color),
            const SizedBox(width: AppTokens.space8),
            _StatChip(
              label: '완료',
              count: done,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space12,
        vertical: AppTokens.space4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTokens.radiusFull),
      ),
      child: Text(
        '$label $count',
        style: theme.textTheme.labelLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error, size: 36),
            const SizedBox(height: AppTokens.space12),
            Text('카테고리를 불러오지 못했어요', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppTokens.space4),
            Text(
              message,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
