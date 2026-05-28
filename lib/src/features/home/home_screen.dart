import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date_format.dart';
import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../domain/todo.dart';
import '../../ui/widgets/dismissible_todo_tile.dart';
import '../../ui/widgets/empty_state.dart';
import '../../ui/widgets/skeleton.dart';
import '../../ui/widgets/undo_snackbar.dart';
import '../todo_actions/todo_actions_controller.dart';
import 'today_providers.dart';

/// 오늘 화면 — 헤더 + 이월 배너 + visible todos 리스트.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTodos = ref.watch(watchTodayTodosProvider);
    final carryoverCount = ref.watch(carryoverCountProvider);
    final now = ref.watch(nowProvider)();

    return asyncTodos.when(
      loading: () => const TodoListSkeleton(),
      error: (e, _) => _Error(message: '$e'),
      data: (todos) => _Loaded(
        todos: todos,
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
      ),
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({
    required this.todos,
    required this.carryoverCount,
    required this.now,
    required this.onToggle,
    required this.onDelete,
  });

  final List<Todo> todos;
  final int carryoverCount;
  final DateTime now;
  final void Function(Todo) onToggle;
  final void Function(Todo) onDelete;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.space24,
            AppTokens.space32,
            AppTokens.space24,
            AppTokens.space16,
          ),
          sliver: SliverToBoxAdapter(child: _Header(now: now)),
        ),
        if (carryoverCount > 0)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.space24),
            sliver: SliverToBoxAdapter(
              child: _CarryoverBanner(count: carryoverCount),
            ),
          ),
        if (todos.isEmpty)
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
            sliver: SliverList.separated(
              itemCount: todos.length,
              itemBuilder: (_, i) => DismissibleTodoTile(
                todo: todos[i],
                onToggle: () => onToggle(todos[i]),
                onDelete: () => onDelete(todos[i]),
              ),
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppTokens.space8),
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
