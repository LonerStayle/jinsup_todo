import 'package:flutter/material.dart';

import '../../core/date_format.dart';
import '../../core/theme.dart';
import '../../domain/todo.dart';

/// 한 줄짜리 Todo 카드 — 카테고리 컬러바 + 제목 + 시간 + 체크 아이콘.
///
/// 체크/편집/삭제 동작은 phase 5 의 "체크 흐름" task 에서 [onToggle] / [onTap] 등으로
/// 연결한다. 지금은 표시만.
class TodoTile extends StatelessWidget {
  const TodoTile({
    super.key,
    required this.todo,
    this.onToggle,
    this.onTap,
    this.onAddChild,
    this.isExpanded,
    this.onToggleExpand,
    this.childCount = 0,
    this.drillChildCount,
  });

  final Todo todo;
  final VoidCallback? onToggle;
  final VoidCallback? onTap;

  /// Task C — "＋ 하위 추가" 콜백. null 이면 버튼 미표시 (note 타입 등). task 만 자식 가능.
  final VoidCallback? onAddChild;

  /// Task C — 접힘/펼침 상태. null 이면 자식이 없어 chevron 미표시. (인라인 트리 전용)
  final bool? isExpanded;

  /// Task C — chevron tap 콜백 (펼침/접힘 토글). isExpanded != null 일 때만 의미.
  final VoidCallback? onToggleExpand;

  /// Task C — 직속 자식 수 (>0 이면 폴더로 간주, 체크 진척률 배지 표시 가능). 현재는
  /// chevron 표시 판단에 isExpanded 와 함께 사용.
  final int childCount;

  /// 기능 M — 드릴다운 모드. non-null 이면 "자식 N + chevron_right" 배지를 trailing
  /// 앞에 표시(드릴 가능 표시). 타일 탭이 상세 화면 push 임을 시각적으로 알린다.
  /// 인라인 펼침(isExpanded) 과는 상호 배타 — 드릴 리스트에서만 사용.
  final int? drillChildCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDone = todo.isDone;
    final isNote = todo.type == TodoType.note;
    // fast-tasks — 모드별 날짜 라벨. isAllDay 면 시간 미출력 (00:00 금지).
    final dateLabel = isNote ? null : TodoDateLabel.format(todo);

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
              // Task C — 자식이 있으면 펼침/접힘 chevron. 없으면 컬러바만.
              if (isExpanded != null)
                InkWell(
                  key: ValueKey('todo-tile-chevron-${todo.id}'),
                  onTap: onToggleExpand,
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: const EdgeInsets.all(AppTokens.space2),
                    child: Icon(
                      isExpanded!
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.keyboard_arrow_right_rounded,
                      size: 20,
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            todo.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              decoration: isDone
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: isDone
                                  ? scheme.onSurface.withValues(alpha: 0.45)
                                  : null,
                              fontStyle: isNote ? FontStyle.italic : null,
                            ),
                          ),
                        ),
                        // v1.2 — description 이 있으면 작은 메모 아이콘으로 힌트 표시.
                        if ((todo.description ?? '').isNotEmpty) ...[
                          const SizedBox(width: AppTokens.space8),
                          Icon(
                            key: const ValueKey('todo-tile-description-hint'),
                            Icons.sticky_note_2_outlined,
                            size: 14,
                            color: scheme.onSurface.withValues(alpha: 0.55),
                          ),
                        ],
                      ],
                    ),
                    if (dateLabel != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppTokens.space2),
                        child: Text(
                          dateLabel,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
              // 기능 M — 드릴 가능 표시. "자식 N" + chevron_right. 탭하면 상세 화면 push.
              if (drillChildCount != null)
                Padding(
                  key: ValueKey('todo-tile-drill-${todo.id}'),
                  padding: const EdgeInsets.only(left: AppTokens.space4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTokens.space8,
                          vertical: AppTokens.space2,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(
                            AppTokens.radiusFull,
                          ),
                        ),
                        child: Text(
                          '하위 $drillChildCount',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: scheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ),
              // Task C — task 타입만 "＋ 하위 추가" 버튼. note 는 자식 불가 → 미표시.
              if (onAddChild != null && !isNote)
                IconButton(
                  key: ValueKey('todo-tile-add-child-${todo.id}'),
                  onPressed: onAddChild,
                  icon: const Icon(Icons.subdirectory_arrow_right_rounded),
                  iconSize: 18,
                  color: scheme.onSurface.withValues(alpha: 0.45),
                  visualDensity: VisualDensity.compact,
                  tooltip: '하위 추가',
                ),
              if (isNote)
                // note 는 체크 개념이 없어 trailing 을 점·노트 아이콘으로 대체. tap 무동작.
                Padding(
                  key: const ValueKey('todo-tile-note-leading'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.space8,
                  ),
                  child: Icon(
                    Icons.sticky_note_2_outlined,
                    size: 20,
                    color: scheme.onSurface.withValues(alpha: 0.45),
                  ),
                )
              else
                IconButton(
                  key: const ValueKey('todo-tile-check'),
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
