import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../domain/todo.dart';
import 'dismissible_todo_tile.dart';

/// 기능 M — "평면 + 드릴다운" 한 단계 리스트 Sliver.
///
/// 인라인 ▸ 펼침(NestedTodoTreeSliver) 을 대체한다. 이 레벨의 [items] (형제 list) 만
/// 한 줄짜리로 그리되, **자식이 있는 항목은 탭 → 드릴다운**(상세 화면 push), **자식이
/// 없는 leaf 항목은 탭 → 편집**으로 분기한다.
///
/// 각 타일에서 체크 토글 / ＋하위추가 / 스와이프 삭제 / 형제 드래그 순서변경은 유지.
/// 자식 유무는 [allTodos] 에서 `parentId == item.id` 인 todo 가 1개 이상 있는지로 판정하고,
/// 그 개수를 chevron 옆 배지(자식 N) 로 표시한다.
///
/// 오늘 / 카테고리 / 상세(TodoDetailScreen) 가 공통으로 사용한다.
class TodoDrillListSliver extends StatelessWidget {
  const TodoDrillListSliver({
    super.key,
    required this.items,
    required this.allTodos,
    required this.onDrillDown,
    required this.onEdit,
    required this.onToggle,
    required this.onAddChild,
    required this.onCopy,
    required this.onDelete,
    required this.onReorderSiblings,
  });

  /// 이 레벨에서 한 줄씩 보일 형제 list (이미 dao 정렬 순서).
  final List<Todo> items;

  /// 전체 todo (자식 개수 판단용). [items] 의 각 항목에 대해 parentId 매칭으로 childCount 계산.
  final List<Todo> allTodos;

  /// 자식이 있는 폴더 항목 탭 → 상세 화면(드릴다운).
  final void Function(Todo folder) onDrillDown;

  /// 자식이 없는 leaf 항목 탭 → 편집 시트.
  final void Function(Todo leaf) onEdit;

  final void Function(Todo) onToggle;

  /// "＋ 하위 추가" — 그 항목을 부모로 자식 생성 sheet 를 연다.
  final void Function(Todo parent) onAddChild;

  /// 더보기(⋮) 메뉴 '복사' — 그 항목을 prefill 한 새 항목 시트를 연다.
  final void Function(Todo) onCopy;

  final void Function(Todo) onDelete;

  /// 같은 부모의 형제 list + (시각 순서 기준) oldIndex/newIndex 로 재정렬.
  final void Function(List<Todo> siblings, int oldIndex, int newIndex)
  onReorderSiblings;

  /// parentId → 직속 자식 수.
  Map<String, int> _childCounts() {
    final counts = <String, int>{};
    for (final t in allTodos) {
      final pid = t.parentId;
      if (pid == null) continue;
      counts[pid] = (counts[pid] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final counts = _childCounts();
    return SliverReorderableList(
      itemCount: items.length,
      onReorder: (oldIndex, newIndex) =>
          onReorderSiblings(items, oldIndex, newIndex),
      itemBuilder: (context, i) {
        final todo = items[i];
        final childCount = counts[todo.id] ?? 0;
        final hasChildren = childCount > 0;
        return Padding(
          key: ValueKey('drill-node-${todo.id}'),
          padding: const EdgeInsets.only(bottom: AppTokens.space8),
          child: ReorderableDelayedDragStartListener(
            index: i,
            child: DismissibleTodoTile(
              todo: todo,
              onToggle: () => onToggle(todo),
              onDelete: () => onDelete(todo),
              // 자식 있으면 드릴, 없으면 편집.
              onTap: () => hasChildren ? onDrillDown(todo) : onEdit(todo),
              // §14 — note 도 자식(헤딩) 보유 가능 → 타입 무관하게 ＋하위 추가 노출.
              onAddChild: () => onAddChild(todo),
              // 더보기(⋮) 메뉴 — 복사 / 편집(이 항목 자체) / 삭제.
              onCopy: () => onCopy(todo),
              onEditItem: () => onEdit(todo),
              // 드릴 가능 표시 — chevron_right + 자식 개수 배지.
              drillChildCount: hasChildren ? childCount : null,
              childCount: childCount,
            ),
          ),
        );
      },
    );
  }
}
