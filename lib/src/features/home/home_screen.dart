import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date_format.dart';
import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../domain/todo.dart';
import 'today_providers.dart';

/// 오늘 화면 — 헤더 + 이월 배너 + visible todos 리스트.
///
/// TodoListItem / AddTodoSheet 등 본격 동작은 다음 phase task 들에서 채운다.
/// 지금은 빈 상태 + 이월 배너 + 단순 ListTile 까지.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTodos = ref.watch(watchTodayTodosProvider);
    final carryoverCount = ref.watch(carryoverCountProvider);
    final now = ref.watch(nowProvider)();

    return asyncTodos.when(
      loading: () => const _Loading(),
      error: (e, _) => _Error(message: '$e'),
      data: (todos) =>
          _Loaded(todos: todos, carryoverCount: carryoverCount, now: now),
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({
    required this.todos,
    required this.carryoverCount,
    required this.now,
  });

  final List<Todo> todos;
  final int carryoverCount;
  final DateTime now;

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
          const SliverFillRemaining(hasScrollBody: false, child: _EmptyState())
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
              itemBuilder: (_, i) => _TodoTile(todo: todos[i]),
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppTokens.space8),
            ),
          ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '오늘',
          style: theme.textTheme.displayMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppTokens.space4),
        Text(KoDate.pretty(now), style: theme.textTheme.bodyMedium),
      ],
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
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space16,
        vertical: AppTokens.space12,
      ),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTokens.radiusM),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.20),
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

class _TodoTile extends StatelessWidget {
  const _TodoTile({required this.todo});

  final Todo todo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space16,
          vertical: AppTokens.space12,
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 36,
              decoration: BoxDecoration(
                color: todo.category.color,
                borderRadius: BorderRadius.circular(AppTokens.radiusS),
              ),
            ),
            const SizedBox(width: AppTokens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    todo.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      decoration: todo.isDone
                          ? TextDecoration.lineThrough
                          : null,
                      color: todo.isDone
                          ? theme.colorScheme.onSurface.withValues(alpha: 0.45)
                          : null,
                    ),
                  ),
                  if (todo.dueAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppTokens.space2),
                      child: Text(
                        KoDate.time(todo.dueAt!),
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              todo.isDone
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked,
              color: todo.isDone
                  ? todo.category.color
                  : theme.colorScheme.onSurface.withValues(alpha: 0.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppTokens.radiusL),
            ),
            child: Icon(
              Icons.check_circle_outline_rounded,
              size: 36,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: AppTokens.space20),
          Text('오늘 할 일이 없어요', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppTokens.space8),
          Text(
            'Cmd+N 으로 빠르게 추가해보세요.',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator(strokeWidth: 2));
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
