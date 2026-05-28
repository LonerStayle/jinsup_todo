import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/category.dart';
import '../../domain/todo.dart';

/// 트리 query / progress 계산용 providers + 도메인 함수.
///
/// outline view 가 카테고리 root 부터 펼쳐가며 사용. carryover/visibility 와는 별개
/// layer — outline 은 트리 구조 자체를 표시 (note 포함), today 는 task 평탄 list.

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
