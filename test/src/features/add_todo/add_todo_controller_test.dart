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
    controller = AddTodoController(
      repo: repo,
      now: () => DateTime.utc(2026, 5, 27, 9, 0),
      calendar: null,
    );
  });

  tearDown(() async => db.close());

  test(
    'add() 가 Todo.create + repo.upsert 호출, 새 id 발급 + createdAt/updatedAt 주입',
    () async {
      final result = await controller.add(
        const AddTodoSubmission(
          title: '회의 정리',
          category: Category.work,
          dueAt: null,
          addToCalendar: false,
        ),
      );
      final created = result.todo;

      expect(created.title, '회의 정리');
      expect(created.category, Category.work);
      expect(created.createdAt, DateTime.utc(2026, 5, 27, 9, 0));
      expect(created.updatedAt, DateTime.utc(2026, 5, 27, 9, 0));
      expect(created.isDone, isFalse);
      expect(created.id, isNotEmpty);
      expect(result.calendarWarning, isNull);

      final fromDb = await repo.getById(created.id);
      expect(fromDb, created);
    },
  );

  test('dueAt 이 있으면 그대로 보존', () async {
    final due = DateTime(2026, 5, 28, 14, 30);
    final result = await controller.add(
      AddTodoSubmission(
        title: 'PR 리뷰',
        category: Category.personalDev,
        dueAt: due,
        addToCalendar: true,
      ),
    );

    expect(result.todo.dueAt, due);
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

    expect(a.todo.id, isNot(b.todo.id));
  });

  test(
    'addToCalendar=true + calendar==null → calendarWarning 메시지 노출',
    () async {
      // setUp 의 controller.calendar 가 null — Google OAuth 미설정 상태 시뮬레이션.
      final result = await controller.add(
        AddTodoSubmission(
          title: 'cal',
          category: Category.work,
          dueAt: DateTime(2026, 5, 28, 14),
          addToCalendar: true,
        ),
      );

      expect(result.calendarWarning, isNotNull);
      expect(result.calendarWarning, contains('Calendar'));
    },
  );

  test('addToCalendar=false → calendarWarning == null (정상 케이스)', () async {
    final result = await controller.add(
      AddTodoSubmission(
        title: 'no cal',
        category: Category.work,
        dueAt: DateTime(2026, 5, 28, 14),
        addToCalendar: false,
      ),
    );
    expect(result.calendarWarning, isNull);
  });
}
