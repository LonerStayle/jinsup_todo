import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/data/local/app_database.dart';
import 'package:solo_todo/src/data/local/local_todo_repository.dart';
import 'package:solo_todo/src/domain/category.dart';
import 'package:solo_todo/src/domain/todo.dart';
import 'package:solo_todo/src/features/todo_actions/todo_actions_controller.dart';

void main() {
  late AppDatabase db;
  late LocalTodoRepository repo;
  late TodoActionsController controller;

  final created = DateTime.utc(2026, 5, 27, 9, 0);

  setUp(() {
    db = AppDatabase.memory();
    repo = LocalTodoRepository(db.todosDao);
    controller = TodoActionsController(repo, () => created);
  });

  tearDown(() async => db.close());

  Todo seed({DateTime? doneAt}) {
    return Todo(
      id: 'a',
      title: '회의',
      category: Category.work,
      dueAt: null,
      doneAt: doneAt,
      createdAt: created,
      updatedAt: created,
      calendarEventId: null,
    );
  }

  test('toggle: 미체크 → 체크 (doneAt 가 now 로 채워짐, updatedAt 갱신)', () async {
    final original = seed();
    await repo.upsert(original);

    final later = DateTime.utc(2026, 5, 27, 10);
    controller = TodoActionsController(repo, () => later);

    final updated = await controller.toggle(original);

    expect(updated.isDone, isTrue);
    expect(updated.doneAt, later);
    expect(updated.updatedAt, later);

    final fromDb = await repo.getById('a');
    expect(fromDb, updated);
  });

  test('toggle: 체크 → 미체크 (doneAt null, updatedAt 갱신)', () async {
    final original = seed(doneAt: DateTime.utc(2026, 5, 27, 10));
    await repo.upsert(original);

    final later = DateTime.utc(2026, 5, 27, 11);
    controller = TodoActionsController(repo, () => later);

    final updated = await controller.toggle(original);

    expect(updated.isDone, isFalse);
    expect(updated.doneAt, isNull);
    expect(updated.updatedAt, later);
  });
}
