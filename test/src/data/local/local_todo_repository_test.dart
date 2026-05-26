import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/data/local/app_database.dart';
import 'package:solo_todo/src/data/local/local_todo_repository.dart';
import 'package:solo_todo/src/domain/category.dart';
import 'package:solo_todo/src/domain/todo.dart';

void main() {
  late AppDatabase db;
  late LocalTodoRepository repo;

  setUp(() {
    db = AppDatabase.memory();
    repo = LocalTodoRepository(db.todosDao);
  });

  tearDown(() async {
    await db.close();
  });

  Todo make({
    required String id,
    String title = 'x',
    Category category = Category.daily,
    DateTime? dueAt,
    DateTime? doneAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final c = createdAt ?? DateTime.utc(2026, 5, 27, 9);
    return Todo(
      id: id,
      title: title,
      category: category,
      dueAt: dueAt,
      doneAt: doneAt,
      createdAt: c,
      updatedAt: updatedAt ?? c,
      calendarEventId: null,
    );
  }

  group('LocalTodoRepository — CRUD', () {
    test('upsert + getById round-trip', () async {
      final t = make(id: 'a', title: '회사 보고', category: Category.work);
      await repo.upsert(t);
      final got = await repo.getById('a');
      expect(got, t);
    });

    test('getById 없으면 null', () async {
      expect(await repo.getById('ghost'), isNull);
    });

    test('upsert 두 번째 호출 = update', () async {
      await repo.upsert(make(id: 'a', title: 'orig'));
      final updatedAt = DateTime.utc(2026, 5, 27, 11);
      await repo.upsert(make(id: 'a', title: 'new', updatedAt: updatedAt));

      final got = await repo.getById('a');
      expect(got, isNotNull);
      expect(got!.title, 'new');
      expect(got.updatedAt, updatedAt);
    });

    test('deleteById 가 row 를 지운다', () async {
      await repo.upsert(make(id: 'a'));
      await repo.deleteById('a');
      expect(await repo.getById('a'), isNull);
    });

    test('deleteById 미존재 키는 no-op', () async {
      await repo.deleteById('ghost'); // throws X
      expect(await repo.getById('ghost'), isNull);
    });
  });

  group('LocalTodoRepository — streams', () {
    test('watchAll: 빈 DB 는 빈 리스트 emit', () async {
      expect(await repo.watchAll().first, isEmpty);
    });

    test('watchAll: 미체크 우선 정렬 — 미체크가 먼저', () async {
      // 체크된 항목
      await repo.upsert(
        make(
          id: 'done',
          doneAt: DateTime.utc(2026, 5, 27, 12),
          createdAt: DateTime.utc(2026, 5, 27, 8),
        ),
      );
      // 미체크 항목
      await repo.upsert(
        make(id: 'undone', createdAt: DateTime.utc(2026, 5, 27, 9)),
      );

      final list = await repo.watchAll().first;
      expect(list.map((t) => t.id).toList(), ['undone', 'done']);
    });

    test('watchByCategory 가 카테고리별로만 emit', () async {
      await repo.upsert(make(id: 'w', category: Category.work));
      await repo.upsert(make(id: 'd', category: Category.daily));

      expect(
        (await repo.watchByCategory(Category.work).first).map((t) => t.id),
        ['w'],
      );
      expect(
        (await repo.watchByCategory(Category.daily).first).map((t) => t.id),
        ['d'],
      );
      expect(await repo.watchByCategory(Category.idea).first, isEmpty);
    });

    test('watchToday: 어제 미체크 + 오늘 미체크 만 visible, 내일 dueAt 은 hide', () async {
      DateTime now() => DateTime(2026, 5, 27, 10);

      await repo.upsert(
        make(
          id: 'y',
          dueAt: DateTime(2026, 5, 26),
          createdAt: DateTime.utc(2026, 5, 26),
        ),
      );
      await repo.upsert(
        make(
          id: 't',
          dueAt: DateTime(2026, 5, 27, 15),
          createdAt: DateTime.utc(2026, 5, 27),
        ),
      );
      await repo.upsert(
        make(
          id: 'm',
          dueAt: DateTime(2026, 5, 28),
          createdAt: DateTime.utc(2026, 5, 27),
        ),
      );

      final list = await repo.watchToday(now).first;
      expect(list.map((t) => t.id).toSet(), {'y', 't'});
    });

    test('watchToday: 어제 doneAt 의 체크된 항목은 hide', () async {
      DateTime now() => DateTime(2026, 5, 27, 10);

      await repo.upsert(
        make(
          id: 'stale',
          doneAt: DateTime(2026, 5, 26, 18),
          createdAt: DateTime.utc(2026, 5, 26, 9),
        ),
      );
      await repo.upsert(
        make(
          id: 'fresh',
          doneAt: DateTime(2026, 5, 27, 9),
          createdAt: DateTime.utc(2026, 5, 27, 8),
        ),
      );

      final list = await repo.watchToday(now).first;
      expect(list.map((t) => t.id), ['fresh']);
    });
  });
}
