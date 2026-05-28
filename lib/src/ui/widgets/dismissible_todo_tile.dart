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
    this.confirmDismiss,
  });

  /// 실수 swipe 방지를 위한 dismiss threshold. 0.4 (40%) 는 의도치 않은 살짝 swipe 으로도
  /// 즉시 삭제되던 case 가 있어 [_kSwipeThreshold] 로 상향. UndoSnackbar 가 회복 경로지만
  /// 1차 가드를 강화하는 게 더 안전.
  static const double _kSwipeThreshold = 0.6;

  final Todo todo;
  final VoidCallback? onToggle;
  final VoidCallback? onDelete;

  /// 선택적 확인 콜백 — true 반환 시에만 dismiss. 일반 todo 는 swipe + UndoSnackbar 로
  /// 충분하지만 중요한 case (예: calendarEventId 있는 todo) 에서 호출자가 dialog 띄울 수 있게.
  final Future<bool> Function()? confirmDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: ValueKey('todo-${todo.id}'),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {DismissDirection.endToStart: _kSwipeThreshold},
      confirmDismiss: confirmDismiss == null
          ? null
          : (_) async => confirmDismiss!(),
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
