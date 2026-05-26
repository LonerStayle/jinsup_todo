import 'package:flutter/material.dart';

import '../../core/date_format.dart';
import '../../core/theme.dart';
import '../../domain/todo.dart';

/// 한 줄짜리 Todo 카드 — 카테고리 컬러바 + 제목 + 시간 + 체크 아이콘.
///
/// 체크/편집/삭제 동작은 phase 5 의 "체크 흐름" task 에서 [onToggle] / [onTap] 등으로
/// 연결한다. 지금은 표시만.
class TodoTile extends StatelessWidget {
  const TodoTile({super.key, required this.todo, this.onToggle, this.onTap});

  final Todo todo;
  final VoidCallback? onToggle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDone = todo.isDone;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusM),
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
                        decoration: isDone ? TextDecoration.lineThrough : null,
                        color: isDone
                            ? scheme.onSurface.withValues(alpha: 0.45)
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
              IconButton(
                onPressed: onToggle,
                icon: Icon(
                  isDone
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked,
                  color: isDone
                      ? todo.category.color
                      : scheme.onSurface.withValues(alpha: 0.35),
                ),
                tooltip: isDone ? '완료 취소' : '완료',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
