import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../domain/todo.dart';
import 'todo_tile.dart';

/// [TodoTile] 을 [Dismissible] 로 감싸 좌→우 swipe 으로 삭제 트리거.
///
/// background 는 errorContainer (Material 3) — 강조이지만 destructive 색 톤. swipe 진행 시
/// 휴지통 아이콘 점차 드러나는 형태.
class DismissibleTodoTile extends StatelessWidget {
  const DismissibleTodoTile({
    super.key,
    required this.todo,
    this.onToggle,
    this.onDelete,
  });

  final Todo todo;
  final VoidCallback? onToggle;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: ValueKey('todo-${todo.id}'),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {DismissDirection.endToStart: 0.4},
      background: const SizedBox.shrink(),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.space20),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(AppTokens.radiusM),
        ),
        child: Icon(
          Icons.delete_outline_rounded,
          color: scheme.onErrorContainer,
        ),
      ),
      onDismissed: (_) => onDelete?.call(),
      child: TodoTile(todo: todo, onToggle: onToggle),
    );
  }
}
