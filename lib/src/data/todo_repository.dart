import '../domain/category.dart';
import '../domain/todo.dart';

/// Todo 영속화 계약.
///
/// 구현체 :
/// - `LocalTodoRepository` — Drift SQLite (오프라인 1차 출처)
/// - `RemoteTodoRepository` — Supabase (동기화 + 다기기 공유)
/// - `SyncingTodoRepository` (phase 7) — 두 어댑터를 합쳐 local-first + remote eventual
///
/// 모든 mutation 은 호출 시점에 [Todo.updatedAt] 이 갱신되어 있어야 한다 (last-write-wins 충돌 해소용).
/// stream API 는 cold/hot 여부를 강제하지 않는다 (구현체 자유).
abstract interface class TodoRepository {
  /// 단일 조회. 없으면 null.
  Future<Todo?> getById(String id);

  /// 모든 Todo. 미체크 우선 + dueAt 오름 + createdAt 내림.
  Stream<List<Todo>> watchAll();

  /// 특정 카테고리만.
  Stream<List<Todo>> watchByCategory(Category category);

  /// 오늘 화면용 — [VisibilityPolicy] 가 적용된 결과.
  /// [now] 는 자정 트리거 갱신 대응을 위해 callable 로 받는다.
  Stream<List<Todo>> watchToday(DateTime Function() now);

  /// id 기준 upsert (없으면 insert, 있으면 전체 update).
  Future<void> upsert(Todo todo);

  Future<void> deleteById(String id);

  /// Task B — 같은 형제 집합(같은 parentId + categoryId)의 최소 sortOrder. 형제가 없으면
  /// null. 신규 생성 / 시트 수정 시 `min - 1` 로 맨 위(작은 sortOrder = 위)에 올릴 때 사용.
  Future<int?> minSiblingSortOrder({
    required String categoryId,
    String? parentId,
  });
}
