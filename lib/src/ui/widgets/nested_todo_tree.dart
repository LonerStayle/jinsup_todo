import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../domain/todo.dart';
import 'dismissible_todo_tile.dart';

/// Task C — 들여쓰기 중첩 트리(접힘 가능)를 그리는 Sliver.
///
/// 오늘 화면 / 카테고리 화면이 공통으로 사용한다. 평면 list 대신 부모-자식 트리를
/// depth 들여쓰기로 렌더하되, 각 노드에서 **스와이프 삭제 + undo + 체크 토글 +
/// 편집 탭 + ＋하위 추가** 가 모두 동작한다.
///
/// 설계:
///   - [roots] : 이 화면이 root 로 표시할 todo 들 (오늘=visible todo, 카테고리=그 카테고리
///     root). 정렬은 호출자(dao) 가 이미 적용한 순서를 그대로 따른다.
///   - [allTodos] : parentId → children 인덱스 구성용. roots 의 자손이 [allTodos] 에
///     있으면 (오늘 화면에서 자식이 '오늘'이 아니어도) 하위 체크리스트가 보인다.
///   - 무한 깊이. 접힌 노드는 [collapsed] set 에 id 보관 (default 펼침).
///
/// 평면화: visible 트리를 (todo, depth) 쌍의 list 로 flatten 한 뒤 SliverList 로 그린다.
/// SliverAnimatedList 의 reorder 애니메이션은 중첩에서 index 가 동적이라 포기하고,
/// 정확성(삭제·체크·편집·undo·중첩)을 우선한다 (CLAUDE.md: 화려함보다 정확성).
class NestedTodoTreeSliver extends StatelessWidget {
  const NestedTodoTreeSliver({
    super.key,
    required this.roots,
    required this.allTodos,
    required this.collapsed,
    required this.onToggleCollapse,
    required this.onToggle,
    required this.onDelete,
    required this.onTap,
    required this.onAddChild,
    this.indentStep = 20.0,
  });

  /// root 노드들 (이미 dao 정렬 순서).
  final List<Todo> roots;

  /// 전체 todo (자식 인덱스 구성용).
  final List<Todo> allTodos;

  /// 접힌 노드 id set. id 가 있으면 접힘.
  final Set<String> collapsed;
  final void Function(String id) onToggleCollapse;

  final void Function(Todo) onToggle;
  final void Function(Todo) onDelete;
  final void Function(Todo) onTap;

  /// "＋ 하위 추가" — 그 노드를 부모로 자식 생성 sheet 를 연다.
  final void Function(Todo parent) onAddChild;

  final double indentStep;

  /// parentId → 그 parent 의 직속 자식들 (allTodos 정렬 순서 보존).
  Map<String, List<Todo>> _childIndex() {
    final byParent = <String, List<Todo>>{};
    for (final t in allTodos) {
      final pid = t.parentId;
      if (pid == null) continue;
      (byParent[pid] ??= []).add(t);
    }
    return byParent;
  }

  /// 트리를 (todo, depth) 평면 list 로 flatten. 접힌 노드의 자식은 제외.
  /// 사이클 방지를 위해 방문 id 추적.
  List<_FlatNode> _flatten() {
    final byParent = _childIndex();
    final result = <_FlatNode>[];
    final visited = <String>{};

    void walk(List<Todo> nodes, int depth) {
      for (final node in nodes) {
        if (!visited.add(node.id)) continue; // 사이클 차단
        final children = byParent[node.id] ?? const <Todo>[];
        result.add(
          _FlatNode(todo: node, depth: depth, childCount: children.length),
        );
        if (children.isNotEmpty && !collapsed.contains(node.id)) {
          walk(children, depth + 1);
        }
      }
    }

    walk(roots, 0);
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final flat = _flatten();
    return SliverList.separated(
      itemCount: flat.length,
      itemBuilder: (_, i) {
        final n = flat[i];
        final todo = n.todo;
        final hasChildren = n.childCount > 0;
        final canAddChild = todo.type == TodoType.task;
        return Padding(
          padding: EdgeInsets.only(left: n.depth * indentStep),
          child: DismissibleTodoTile(
            todo: todo,
            onToggle: () => onToggle(todo),
            onDelete: () => onDelete(todo),
            onTap: () => onTap(todo),
            onAddChild: canAddChild ? () => onAddChild(todo) : null,
            isExpanded: hasChildren ? !collapsed.contains(todo.id) : null,
            onToggleExpand: hasChildren
                ? () => onToggleCollapse(todo.id)
                : null,
            childCount: n.childCount,
          ),
        );
      },
      separatorBuilder: (_, _) => const SizedBox(height: AppTokens.space8),
    );
  }
}

class _FlatNode {
  const _FlatNode({
    required this.todo,
    required this.depth,
    required this.childCount,
  });

  final Todo todo;
  final int depth;
  final int childCount;
}
