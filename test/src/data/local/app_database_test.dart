import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/data/local/app_database.dart';
import 'package:solo_todo/src/data/local/local_todo_repository.dart';
import 'package:solo_todo/src/domain/category.dart';
import 'package:solo_todo/src/domain/todo.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.memory());
  tearDown(() async => db.close());

  Todo make(String id) => Todo(
    id: id,
    title: id,
    category: Category.daily,
    dueAt: null,
    doneAt: null,
    createdAt: DateTime.utc(2026, 5, 27, 9),
    updatedAt: DateTime.utc(2026, 5, 27, 9),
    calendarEventId: null,
  );

  test('clearAllUserData — todos + outbox 모두 비워짐', () async {
    final repo = LocalTodoRepository(db.todosDao);

    // todos 와 outbox 모두 채운다.
    await repo.upsert(make('a'));
    await repo.upsert(make('b'));
    await db.outboxDao.enqueue(
      OutboxRow(
        id: 'o1',
        kind: 'upsert',
        todoId: 'a',
        payload: null,
        createdAt: DateTime.utc(2026, 5, 27, 9),
      ),
    );
    await db.outboxDao.enqueue(
      OutboxRow(
        id: 'o2',
        kind: 'delete',
        todoId: 'b',
        payload: null,
        createdAt: DateTime.utc(2026, 5, 27, 9),
      ),
    );

    expect(await db.todosDao.getById('a'), isNotNull);
    expect(await db.outboxDao.count(), 2);

    await db.clearAllUserData();

    expect(
      await db.todosDao.getById('a'),
      isNull,
      reason: 'sign-out 후 todos 가 남아 있으면 다음 user 에게 노출됨',
    );
    expect(await db.todosDao.getById('b'), isNull);
    expect(await db.outboxDao.count(), 0);
  });

  test('clearAllUserData — 빈 상태에서 호출해도 에러 없음 (멱등)', () async {
    expect(await db.outboxDao.count(), 0);
    await db.clearAllUserData();
    expect(await db.outboxDao.count(), 0);
  });
}
