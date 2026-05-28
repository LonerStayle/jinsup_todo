import 'package:drift/drift.dart';

import '../../domain/category.dart';
import '../../domain/policies/visibility_policy.dart';
import '../../domain/todo.dart' as domain;
import 'app_database.dart';

part 'todos_dao.g.dart';

/// Todo CRUD + 조회 스트림.
///
/// 모든 외부 인터페이스는 도메인 [domain.Todo] 만 노출. Drift 의 [TodoRow] 는 내부 매핑용.
@DriftAccessor(tables: [Todos])
class TodosDao extends DatabaseAccessor<AppDatabase> with _$TodosDaoMixin {
  TodosDao(super.db);

  Future<domain.Todo?> getById(String id) async {
    final row = await (select(
      todos,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _rowToDomain(row);
  }

  /// id 기준 upsert (없으면 insert, 있으면 전체 update).
  Future<void> upsert(domain.Todo todo) {
    return into(todos).insertOnConflictUpdate(_domainToCompanion(todo));
  }

  Future<int> deleteById(String id) {
    return (delete(todos)..where((t) => t.id.equals(id))).go();
  }

  /// 미체크 우선 + sortOrder 오름 + dueAt 오름 + createdAt 내림 정렬.
  ///
  /// v1.1 — sortOrder 가 사용자 정의 순서 (drag-reorder 는 v1.2 후속). 같은 sortOrder
  /// 인 경우 dueAt → createdAt 으로 자연 fallback. 모두 기본값 0 일 때는 기존 v1.0
  /// 정렬과 동일하게 동작.
  Stream<List<domain.Todo>> watchAll() {
    final q = select(todos)
      ..orderBy([
        // 미체크 (doneAt IS NULL) 가 항상 먼저 오도록 NULLS FIRST 명시.
        // SQLite ASC 의 default 도 NULLS FIRST 이지만 미래 호환 + 의도 표시 차원에서 명시.
        (t) => OrderingTerm(
          expression: t.doneAt,
          mode: OrderingMode.asc,
          nulls: NullsOrder.first,
        ),
        (t) => OrderingTerm(expression: t.sortOrder, mode: OrderingMode.asc),
        (t) => OrderingTerm(expression: t.dueAt, mode: OrderingMode.asc),
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
      ]);
    return q.watch().map((rows) => rows.map(_rowToDomain).toList());
  }

  Stream<List<domain.Todo>> watchByCategory(Category category) {
    final q = select(todos)
      ..where((t) => t.category.equals(category.id))
      ..orderBy([
        (t) => OrderingTerm(expression: t.doneAt, mode: OrderingMode.asc),
        (t) => OrderingTerm(expression: t.sortOrder, mode: OrderingMode.asc),
        (t) => OrderingTerm(expression: t.dueAt, mode: OrderingMode.asc),
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
      ]);
    return q.watch().map((rows) => rows.map(_rowToDomain).toList());
  }

  /// 오늘 화면용 스트림.
  ///
  /// [VisibilityPolicy] 가 도메인 정책의 단일 출처이므로, SQL 측 필터링 대신
  /// 클라이언트에서 한 번에 적용한다. 1인 사용자 데이터 양 (~수백 건) 기준 성능 충분.
  Stream<List<domain.Todo>> watchToday(DateTime Function() now) {
    return watchAll().map(
      (all) =>
          all.where((t) => VisibilityPolicy.isVisibleToday(t, now())).toList(),
    );
  }

  /// 특정 parent 의 직속 자식들 stream — outline view 의 펼침에 사용.
  /// 정렬: sortOrder asc → createdAt asc. note 도 포함 (outline 은 트리 전체 표시).
  Stream<List<domain.Todo>> watchChildrenOf(String parentId) {
    final q = select(todos)
      ..where((t) => t.parentId.equals(parentId))
      ..orderBy([
        (t) => OrderingTerm(expression: t.sortOrder, mode: OrderingMode.asc),
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc),
      ]);
    return q.watch().map((rows) => rows.map(_rowToDomain).toList());
  }

  /// 특정 카테고리의 root 노드들 stream (parent_id IS NULL).
  Stream<List<domain.Todo>> watchRootsOfCategory(Category category) {
    final q = select(todos)
      ..where((t) => t.parentId.isNull() & t.category.equals(category.id))
      ..orderBy([
        (t) => OrderingTerm(expression: t.sortOrder, mode: OrderingMode.asc),
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc),
      ]);
    return q.watch().map((rows) => rows.map(_rowToDomain).toList());
  }

  // --- 매핑 헬퍼 ---------------------------------------------------------

  domain.Todo _rowToDomain(TodoRow row) {
    return domain.Todo(
      id: row.id,
      title: row.title,
      category: Category.fromId(row.category),
      dueAt: row.dueAt,
      doneAt: row.doneAt,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      calendarEventId: row.calendarEventId,
      parentId: row.parentId,
      type: _parseType(row.type),
      sortOrder: row.sortOrder,
    );
  }

  /// 옛 row 또는 외부에서 미지의 type 문자열이 들어와도 안전하게 task 로 fallback.
  static domain.TodoType _parseType(String raw) {
    switch (raw) {
      case 'note':
        return domain.TodoType.note;
      case 'task':
      default:
        return domain.TodoType.task;
    }
  }

  TodosCompanion _domainToCompanion(domain.Todo t) {
    return TodosCompanion(
      id: Value(t.id),
      title: Value(t.title),
      category: Value(t.category.id),
      dueAt: Value(t.dueAt),
      doneAt: Value(t.doneAt),
      createdAt: Value(t.createdAt),
      updatedAt: Value(t.updatedAt),
      calendarEventId: Value(t.calendarEventId),
      parentId: Value(t.parentId),
      type: Value(t.type.name),
      sortOrder: Value(t.sortOrder),
    );
  }
}
