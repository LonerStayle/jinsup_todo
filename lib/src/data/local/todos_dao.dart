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

  /// 미체크 우선 + dueAt 오름 + createdAt 내림 정렬.
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
    );
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
    );
  }
}
