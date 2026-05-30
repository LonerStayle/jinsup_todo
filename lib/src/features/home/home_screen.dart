import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date_format.dart';
import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../domain/todo.dart';
import '../../ui/widgets/empty_state.dart';
import '../../ui/widgets/nested_todo_tree.dart';
import '../../ui/widgets/skeleton.dart';
import '../../ui/widgets/undo_snackbar.dart';
import '../add_todo/add_todo_controller.dart';
import '../add_todo/add_todo_sheet.dart';
import '../outline/tree_providers.dart';
import '../todo_actions/todo_actions_controller.dart';
import 'today_providers.dart';

/// 오늘 화면 — 헤더 + 이월 배너 + visible todos 리스트.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTodos = ref.watch(watchTodayTodosProvider);
    final carryoverCount = ref.watch(carryoverCountProvider);
    final allTodos = ref.watch(allTodosProvider).asData?.value ?? const [];
    final now = ref.watch(nowProvider)();

    return asyncTodos.when(
      loading: () => const TodoListSkeleton(),
      error: (e, _) => _Error(message: '$e'),
      data: (todos) => _Loaded(
        todos: todos,
        allTodos: allTodos,
        carryoverCount: carryoverCount,
        now: now,
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
        // v1.2 — tile tap → AddTodoSheet edit 모드 진입.
        onTap: (t) async {
          await AddTodoSheet.show(
            context,
            initialCategory: t.category,
            initialTodo: t,
            onSubmit: (_) {}, // edit 모드에선 호출 안 됨.
            onUpdate: (updated) {
              ref.read(todoActionsProvider).update(updated);
            },
          );
        },
        // Task C — ＋ 하위 추가.
        onAddChild: (parent) => showAddChildSheet(context, ref, parent: parent),
        // Task B — 형제 드래그 재정렬.
        onReorderSiblings: (siblings, oldIndex, newIndex) => ref
            .read(todoActionsProvider)
            .reorderSiblings(siblings, oldIndex, newIndex),
      ),
    );
  }
}

class _Loaded extends StatefulWidget {
  const _Loaded({
    required this.todos,
    required this.allTodos,
    required this.carryoverCount,
    required this.now,
    required this.onToggle,
    required this.onDelete,
    required this.onTap,
    required this.onAddChild,
    required this.onReorderSiblings,
  });

  /// 오늘 화면에서 root 로 보일 todo (visibility/carryover 정책 적용된 visible set).
  /// 이 todo 들의 자손은 '오늘'이 아니어도 [allTodos] 인덱스로 하위 체크리스트가 펼쳐진다.
  final List<Todo> todos;
  final List<Todo> allTodos;
  final int carryoverCount;
  final DateTime now;
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
  /// 접힌 노드 id set (default 펼침).
  final Set<String> _collapsed = {};

  void _toggleCollapse(String id) {
    setState(() {
      if (!_collapsed.remove(id)) _collapsed.add(id);
    });
  }

  /// 오늘 화면 root 후보: visible todo 중 그 부모도 visible 인 항목은 자식으로만 보여야
  /// 중복되지 않는다. 부모가 today set 에 있으면 그 부모 아래 자식으로 자연 렌더되므로
  /// root 목록에서 제외. (부모가 today 가 아니면 이 visible 자식이 root 로 올라온다.)
  List<Todo> get _roots {
    final visibleIds = widget.todos.map((t) => t.id).toSet();
    return widget.todos
        .where((t) => t.parentId == null || !visibleIds.contains(t.parentId))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final roots = _roots;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.space24,
            AppTokens.space32,
            AppTokens.space24,
            AppTokens.space16,
          ),
          sliver: SliverToBoxAdapter(child: _Header(now: widget.now)),
        ),
        if (widget.carryoverCount > 0)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.space24),
            sliver: SliverToBoxAdapter(
              child: _CarryoverBanner(count: widget.carryoverCount),
            ),
          ),
        if (widget.todos.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.check_circle_outline_rounded,
              title: '오늘 할 일이 없어요',
              subtitle: 'Cmd+N 으로 빠르게 추가해보세요.',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.space24,
              AppTokens.space16,
              AppTokens.space24,
              AppTokens.space48,
            ),
            sliver: NestedTodoTreeSliver(
              roots: roots,
              allTodos: widget.allTodos,
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

class _Header extends ConsumerWidget {
  const _Header({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pendingCount = ref.watch(outboxCountProvider).value ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '오늘',
              style: theme.textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            if (pendingCount > 0)
              _SyncPendingChip(count: pendingCount, theme: theme),
          ],
        ),
        const SizedBox(height: AppTokens.space4),
        Text(KoDate.pretty(now), style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

class _SyncPendingChip extends StatelessWidget {
  const _SyncPendingChip({required this.count, required this.theme});

  final int count;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    return Container(
      key: const ValueKey('sync-pending-chip'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space12,
        vertical: AppTokens.space4,
      ),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(AppTokens.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_sync_outlined,
            size: 14,
            color: scheme.onTertiaryContainer,
          ),
          const SizedBox(width: AppTokens.space4),
          Text(
            '동기화 대기 $count건',
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onTertiaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CarryoverBanner extends StatelessWidget {
  const _CarryoverBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // 다크 모드에서 alpha 0.08 은 거의 안 보여 가독성이 떨어진다. 다크에서 대비 강화.
    final isDark = theme.brightness == Brightness.dark;
    final bgAlpha = isDark ? 0.18 : 0.08;
    final borderAlpha = isDark ? 0.40 : 0.20;
    return Container(
      key: const ValueKey('carryover-banner'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space16,
        vertical: AppTokens.space12,
      ),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: bgAlpha),
        borderRadius: BorderRadius.circular(AppTokens.radiusM),
        border: Border.all(
          color: scheme.primary.withValues(alpha: borderAlpha),
          width: AppTokens.hairline,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.history_toggle_off_outlined,
            size: 20,
            color: scheme.primary,
          ),
          const SizedBox(width: AppTokens.space12),
          Expanded(
            child: Text(
              '어제까지 못 끝낸 $count건이 오늘로 이월되었어요.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
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
            Text('오늘 화면을 불러오지 못했어요', style: theme.textTheme.titleMedium),
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
