import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/category.dart';
import '../../domain/todo.dart';

/// 트리 query / progress 계산용 providers + 도메인 함수.
///
/// outline view 가 카테고리 root 부터 펼쳐가며 사용. carryover/visibility 와는 별개
/// layer — outline 은 트리 구조 자체를 표시 (note 포함), today 는 task 평탄 list.

/// 사용자의 모든 todos stream — subtree progress 계산에 사용.
/// outline view 는 root + 자식을 별도 stream 으로 받지만, 진척률 계산은 트리 전체를
/// 한 번 walk 해야 하므로 평탄 list 가 편하다.
final allTodosProvider = StreamProvider<List<Todo>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.todosDao.watchAll();
});

/// 특정 parent_id 직속 자식 stream. parent_id 가 null 인 root 은 별도 provider
/// ([rootsOfCategoryProvider]) 를 쓴다.
final childrenOfProvider = StreamProvider.family<List<Todo>, String>((
  ref,
  parentId,
) {
  final db = ref.watch(appDatabaseProvider);
  return db.todosDao.watchChildrenOf(parentId);
});

/// 카테고리 root 의 직속 children — outline view 의 카테고리 헤더 아래 첫 단계.
final rootsOfCategoryProvider = StreamProvider.family<List<Todo>, Category>((
  ref,
  category,
) {
  final db = ref.watch(appDatabaseProvider);
  return db.todosDao.watchRootsOfCategory(category);
});

// ── Task D: 전체보기 [체크리스트] / [메모] 탭 분리용 필터 provider ──
//
// 체크리스트 탭 = task 트리만 (note 제외). 메모 탭 = note 만 (트리 무관 평탄 목록).
// DB 쿼리를 새로 추가하지 않고 기존 stream 을 in-memory 필터링한다 (스키마 무변경,
// 1인 사용자 규모에서 비용 무시 가능). 이렇게 하면 BC 에이전트가 만든 DAO 를 건드리지
// 않고 D 단독으로 완결된다.

/// §14 — 노드의 자손(재귀) 중 task 가 하나라도 있으면 true.
///
/// note 가 task 자손을 가지면 "섹션 헤딩" 으로 간주해 체크리스트 탭에 노출하고,
/// task 자손이 없는 순수 메모(트리)는 메모 탭에만 둔다.
bool hasTaskDescendant(Todo node, List<Todo> all) {
  final byParent = <String, List<Todo>>{};
  for (final t in all) {
    final pid = t.parentId;
    if (pid == null) continue;
    (byParent[pid] ??= []).add(t);
  }
  bool walk(String id) {
    for (final c in byParent[id] ?? const <Todo>[]) {
      if (c.type == TodoType.task) return true;
      if (walk(c.id)) return true;
    }
    return false;
  }

  return walk(node.id);
}

/// 체크리스트 탭에 노출될 자격 — task 본인 또는 task 자손을 가진 note(헤딩).
bool _isChecklistRelevant(Todo t, List<Todo> all) =>
    t.type == TodoType.task || hasTaskDescendant(t, all);

/// 카테고리 root 중 **체크리스트 관련** — task root + task 자손 보유 note 헤딩 root.
///
/// task 자손이 없는 순수 메모 root 는 제외(메모 탭으로). base [rootsOfCategoryProvider]
/// 의 AsyncValue 를 그대로 따라가며 data 일 때만 필터를 건다 (Riverpod 3 — `.stream` 없음).
final taskRootsOfCategoryProvider =
    Provider.family<AsyncValue<List<Todo>>, Category>((ref, category) {
      final all = ref.watch(allTodosProvider).asData?.value ?? const <Todo>[];
      return ref
          .watch(rootsOfCategoryProvider(category))
          .whenData(
            (roots) =>
                roots.where((t) => _isChecklistRelevant(t, all)).toList(),
          );
    });

/// 특정 parent 의 직속 자식 중 **체크리스트 관련** (task + task 자손 보유 note 헤딩).
final childTasksOfProvider = Provider.family<AsyncValue<List<Todo>>, String>((
  ref,
  parentId,
) {
  final all = ref.watch(allTodosProvider).asData?.value ?? const <Todo>[];
  return ref
      .watch(childrenOfProvider(parentId))
      .whenData(
        (children) =>
            children.where((t) => _isChecklistRelevant(t, all)).toList(),
      );
});

/// 카테고리별 **순수 메모 목록** — 메모 탭. task 자손을 가진 헤딩 note 는 제외(그건
/// 체크리스트 탭으로). 트리 깊이 무관하게 그 카테고리의 순수 메모를 평탄 나열한다.
final notesOfCategoryProvider =
    Provider.family<AsyncValue<List<Todo>>, Category>((ref, category) {
      return ref
          .watch(allTodosProvider)
          .whenData(
            (all) => all
                .where(
                  (t) =>
                      t.type == TodoType.note &&
                      t.category.id == category.id &&
                      !hasTaskDescendant(t, all),
                )
                .toList(),
          );
    });

/// 서브트리의 진척률 — `(doneCount, taskCount)`. note 는 분모/분자 모두 제외.
///
/// outline view 의 폴더 헤더 `[N/M]` 라벨에 사용. 자식이 없으면 (0, 0).
class SubtreeProgress {
  const SubtreeProgress({required this.doneCount, required this.taskCount});

  /// 완료된 task 수.
  final int doneCount;

  /// task 총 수 (note 제외).
  final int taskCount;

  /// task 가 1 이상 있으면 비율, 없으면 null.
  double? get ratio => taskCount == 0 ? null : doneCount / taskCount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SubtreeProgress &&
          doneCount == other.doneCount &&
          taskCount == other.taskCount);

  @override
  int get hashCode => Object.hash(doneCount, taskCount);

  @override
  String toString() => 'SubtreeProgress($doneCount/$taskCount)';
}

/// [todo] 의 root 까지의 부모 chain (자기 자신 제외) 을 root → 직속부모 순으로 반환.
///
/// 예: 회사 > 넥서스 > 캔버스 todo 의 path = ['넥서스']. 회사 > 캔버스 todo (root) = [].
///
/// today list 의 breadcrumb 표시 등에 사용. parent_id 가 [all] 에 없으면 (dangling
/// reference — 동기화 race) 거기서 walk 중단.
List<Todo> computeTodoPath(Todo todo, List<Todo> all) {
  // id → Todo 인덱스 1회 구성.
  final byId = {for (final t in all) t.id: t};
  final result = <Todo>[];
  var current = todo;
  // 사이클 방지 — todo 자신 또는 이미 방문한 id 만나면 중단.
  final visited = <String>{todo.id};
  while (current.parentId != null) {
    final parent = byId[current.parentId];
    if (parent == null || !visited.add(parent.id)) break;
    result.insert(0, parent);
    current = parent;
  }
  return result;
}

/// [root] 의 모든 후손 (재귀적으로 트리 walk) 의 진척률 계산.
///
/// [all] 은 같은 사용자의 전체 todos (또는 적어도 [root] 의 모든 자손 포함). 1인 사용자
/// 평균 데이터 규모 (~수백 건) 기준 한 번 SELECT 후 in-memory 처리가 충분히 빠르다.
///
/// 규칙:
///   - root 자기 자신은 카운트에 포함 X (헤더의 [N/M] 은 "내부 진척률" 의미).
///   - note 는 분자/분모 모두 제외.
///   - 자손 task 중 doneAt 가 있으면 done.
SubtreeProgress computeSubtreeProgress(Todo root, List<Todo> all) {
  // parentId → List<Todo> 인덱스 한 번만 구성 (O(N)).
  final byParent = <String, List<Todo>>{};
  for (final t in all) {
    final pid = t.parentId;
    if (pid == null) continue;
    (byParent[pid] ??= []).add(t);
  }

  var done = 0;
  var total = 0;
  void walk(String parentId) {
    final children = byParent[parentId];
    if (children == null) return;
    for (final c in children) {
      if (c.type == TodoType.task) {
        total += 1;
        if (c.isDone) done += 1;
      }
      walk(c.id);
    }
  }

  walk(root.id);
  return SubtreeProgress(doneCount: done, taskCount: total);
}
