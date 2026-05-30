import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../domain/todo.dart';
import 'dismissible_todo_tile.dart';

/// Task C — 들여쓰기 중첩 트리(접힘 가능)를 그리는 Sliver.
/// Task B — 같은 부모의 형제 사이 길게-눌러 드래그 순서변경 (within-sibling) 포함.
///
/// 오늘 화면 / 카테고리 화면이 공통으로 사용한다. 평면 list 대신 부모-자식 트리를
/// depth 들여쓰기로 렌더하되, 각 노드에서 **스와이프 삭제 + undo + 체크 토글 +
/// 편집 탭 + ＋하위 추가 + 형제 드래그 재정렬** 이 모두 동작한다.
///
/// 설계:
///   - [roots] : 이 화면이 root 로 표시할 todo. 정렬은 호출자(dao) 가 적용한 순서.
///   - [allTodos] : parentId → children 인덱스 구성용. roots 의 자손이 [allTodos] 에
///     있으면 (오늘 화면에서 자식이 '오늘'이 아니어도) 하위 체크리스트가 보인다.
///   - 무한 깊이. 접힌 노드는 [collapsed] set 에 id 보관 (default 펼침).
///
/// 평면화: visible 트리를 (todo, depth, parentKey) 쌍으로 flatten 한 뒤
/// [SliverReorderableList] 로 그린다. 드래그는 **같은 parentKey 형제 사이에서만** 허용
/// (다른 부모로의 이동은 무시) — 화려한 풀 DnD 대신 정확성·동기화 우선
/// (CLAUDE.md: 화려함보다 정확성).
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
    required this.onReorderSiblings,
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

  /// Task B — 같은 부모의 형제 list + (시각 순서 기준) oldIndex/newIndex 로 재정렬.
  final void Function(List<Todo> siblings, int oldIndex, int newIndex)
  onReorderSiblings;

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

  /// 트리를 평면 list 로 flatten. 접힌 노드의 자식은 제외. 사이클 방지.
  List<_FlatNode> _flatten() {
    final byParent = _childIndex();
    final result = <_FlatNode>[];
    final visited = <String>{};

    void walk(List<Todo> nodes, int depth, String parentKey) {
      for (final node in nodes) {
        if (!visited.add(node.id)) continue; // 사이클 차단
        final children = byParent[node.id] ?? const <Todo>[];
        result.add(
          _FlatNode(
            todo: node,
            depth: depth,
            childCount: children.length,
            parentKey: parentKey,
            siblings: nodes,
          ),
        );
        if (children.isNotEmpty && !collapsed.contains(node.id)) {
          walk(children, depth + 1, node.id);
        }
      }
    }

    // root 의 parentKey 는 `<root>` 로 묶는다 (모든 root 가 한 형제 집합).
    walk(roots, 0, '<root>');
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final flat = _flatten();
    return SliverReorderableList(
      itemCount: flat.length,
      onReorder: (oldFlatIndex, newFlatIndex) {
        final from = flat[oldFlatIndex];
        // SliverReorderableList 의 newIndex 는 제거 전 기준. target 위치의 노드를 찾는다.
        // 같은 parentKey 형제 사이의 이동만 허용.
        final clampedNew = newFlatIndex > flat.length - 1
            ? flat.length - 1
            : newFlatIndex;
        // newFlatIndex 가 from 보다 뒤면 그 자리는 제거 후 한 칸 당겨지므로 -1 위치를 본다.
        final refIndex = newFlatIndex > oldFlatIndex
            ? clampedNew - 1
            : clampedNew;
        if (refIndex < 0 || refIndex >= flat.length) return;
        final to = flat[refIndex];
        if (to.parentKey != from.parentKey) return; // 다른 부모로는 이동 불가

        final siblings = from.siblings;
        final oldIdx = siblings.indexWhere((t) => t.id == from.todo.id);
        final newIdx = siblings.indexWhere((t) => t.id == to.todo.id);
        if (oldIdx < 0 || newIdx < 0) return;
        onReorderSiblings(siblings, oldIdx, newIdx);
      },
      itemBuilder: (context, i) {
        final n = flat[i];
        final todo = n.todo;
        final hasChildren = n.childCount > 0;
        final canAddChild = todo.type == TodoType.task;
        return Padding(
          // SliverReorderableList 는 각 child 에 고유 Key 필요.
          key: ValueKey('tree-node-${todo.id}'),
          padding: EdgeInsets.only(
            left: n.depth * indentStep,
            bottom: AppTokens.space8,
          ),
          child: ReorderableDelayedDragStartListener(
            index: i,
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
          ),
        );
      },
    );
  }
}

class _FlatNode {
  const _FlatNode({
    required this.todo,
    required this.depth,
    required this.childCount,
    required this.parentKey,
    required this.siblings,
  });

  final Todo todo;
  final int depth;
  final int childCount;

  /// 같은 부모 묶음 식별자 (root 는 `<root>`, 그 외 parentId).
  final String parentKey;

  /// 이 노드가 속한 형제 list (시각 순서). 재정렬 시 그대로 전달.
  final List<Todo> siblings;
}
