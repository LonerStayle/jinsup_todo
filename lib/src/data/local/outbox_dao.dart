import 'package:drift/drift.dart';

import 'app_database.dart';

part 'outbox_dao.g.dart';

@DriftAccessor(tables: [OutboxEntries])
class OutboxDao extends DatabaseAccessor<AppDatabase> with _$OutboxDaoMixin {
  OutboxDao(super.db);

  /// FIFO 순서 (createdAt asc) 로 pending entry 전부 반환.
  Future<List<OutboxRow>> allOrdered() {
    final q = select(outboxEntries)
      ..orderBy([
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc),
      ]);
    return q.get();
  }

  Future<void> enqueue(OutboxRow row) {
    return into(outboxEntries).insertOnConflictUpdate(
      OutboxEntriesCompanion(
        id: Value(row.id),
        kind: Value(row.kind),
        todoId: Value(row.todoId),
        payload: Value(row.payload),
        createdAt: Value(row.createdAt),
      ),
    );
  }

  Future<int> removeById(String id) =>
      (delete(outboxEntries)..where((t) => t.id.equals(id))).go();

  Future<int> count() async {
    final rows = await select(outboxEntries).get();
    return rows.length;
  }

  /// 큐 길이 변동 stream — UI 의 "동기화 대기" indicator 갱신용.
  Stream<int> watchCount() {
    return select(outboxEntries).watch().map((rows) => rows.length);
  }
}
