import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/data/local/app_database.dart';
import 'package:solo_todo/src/data/local/local_todo_repository.dart';
import 'package:solo_todo/src/domain/category.dart';
import 'package:solo_todo/src/features/add_todo/add_todo_controller.dart';
import 'package:solo_todo/src/features/add_todo/add_todo_sheet.dart';

void main() {
  late AppDatabase db;
  late LocalTodoRepository repo;
  late AddTodoController controller;

  setUp(() {
    db = AppDatabase.memory();
    repo = LocalTodoRepository(db.todosDao);
    controller = AddTodoController(repo, () => DateTime.utc(2026, 5, 27, 9, 0));
  });

  tearDown(() async => db.close());

  test(
    'add() 가 Todo.create + repo.upsert 호출, 새 id 발급 + createdAt/updatedAt 주입',
    () async {
      final created = await controller.add(
        const AddTodoSubmission(
          title: '회의 정리',
          category: Category.work,
          dueAt: null,
          addToCalendar: false,
        ),
      );

      expect(created.title, '회의 정리');
      expect(created.category, Category.work);
      expect(created.createdAt, DateTime.utc(2026, 5, 27, 9, 0));
      expect(created.updatedAt, DateTime.utc(2026, 5, 27, 9, 0));
      expect(created.isDone, isFalse);
      expect(created.id, isNotEmpty);

      final fromDb = await repo.getById(created.id);
      expect(fromDb, created);
    },
  );

  test('dueAt 이 있으면 그대로 보존', () async {
    final due = DateTime(2026, 5, 28, 14, 30);
    final created = await controller.add(
      AddTodoSubmission(
        title: 'PR 리뷰',
        category: Category.personalDev,
        dueAt: due,
        addToCalendar: true, // phase 8 에서 처리 — 지금은 todo 자체에 영향 X
      ),
    );

    expect(created.dueAt, due);
  });

  test('서로 다른 호출은 서로 다른 id 발급 (uuid)', () async {
    final a = await controller.add(
      const AddTodoSubmission(
        title: 'a',
        category: Category.daily,
        dueAt: null,
        addToCalendar: false,
      ),
    );
    final b = await controller.add(
      const AddTodoSubmission(
        title: 'b',
        category: Category.daily,
        dueAt: null,
        addToCalendar: false,
      ),
    );

    expect(a.id, isNot(b.id));
  });
}
