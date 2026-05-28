import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/data/local/app_database.dart';
import 'package:solo_todo/src/domain/category.dart';
import 'package:solo_todo/src/domain/todo.dart';

/// CategoriesDao 검증 — CRUD + 정렬 + 안 todos 카운트.
///
/// 매 테스트는 in-memory AppDatabase 로 fresh start. onCreate 가 자동으로 5
/// builtin 을 seed 하므로 [Category.builtinSeeds] 가 baseline 상태.
void main() {
  group('CategoriesDao', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.memory();
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'onCreate seed 후 watchAll 이 5 builtin 을 sortOrder asc 로 emit',
      () async {
        final list = await db.categoriesDao.watchAll().first;
        expect(list.length, 5);
        expect(list.map((c) => c.id).toList(), [
          'work',
          'personal_dev',
          'daily',
          'longterm',
          'idea',
        ]);
        for (final c in list) {
          expect(c.isBuiltin, isTrue);
        }
      },
    );

    test('upsert — 새 카테고리 추가 + sortOrder 순서 반영', () async {
      const custom = Category(
        id: 'custom-1',
        label: '독서',
        iconCodePoint: 0xe865, // book
        colorValue: 0xFFFFA500,
        sortOrder: 10,
        isBuiltin: false,
      );
      await db.categoriesDao.upsert(custom);

      final list = await db.categoriesDao.watchAll().first;
      expect(list.length, 6);
      // builtin 0~4 이후에 sortOrder 10 의 'custom-1' 이 위치.
      expect(list.last.id, 'custom-1');
      expect(list.last.label, '독서');
      expect(list.last.isBuiltin, isFalse);
    });

    test('upsert — 같은 id 면 update (label 갱신)', () async {
      const updated = Category(
        id: 'work',
        label: '회사 업무 (변경)',
        iconCodePoint: 0xef0a,
        colorValue: 0xFF2A66FF,
        sortOrder: 0,
        isBuiltin: true,
      );
      await db.categoriesDao.upsert(updated);

      final got = await db.categoriesDao.getById('work');
      expect(got, isNotNull);
      expect(got!.label, '회사 업무 (변경)');
    });

    test('deleteById — builtin 도 hard delete 가능', () async {
      await db.categoriesDao.deleteById('idea');

      final list = await db.categoriesDao.watchAll().first;
      expect(list.length, 4);
      expect(list.any((c) => c.id == 'idea'), isFalse);
    });

    test('countTodosOfCategory — 안 todos 가 1 이상이면 양수', () async {
      // categories 가 onCreate seed 됐고, todos 는 비어 있는 상태에서 시작.
      expect(await db.categoriesDao.countTodosOfCategory('work'), 0);

      // work 에 todo 2건, daily 에 1건 추가.
      await db.todosDao.upsert(
        Todo(
          id: 't1',
          title: '회사 업무 1',
          category: Category.work,
          createdAt: DateTime.utc(2026, 5, 28),
          updatedAt: DateTime.utc(2026, 5, 28),
        ),
      );
      await db.todosDao.upsert(
        Todo(
          id: 't2',
          title: '회사 업무 2',
          category: Category.work,
          createdAt: DateTime.utc(2026, 5, 28, 1),
          updatedAt: DateTime.utc(2026, 5, 28, 1),
        ),
      );
      await db.todosDao.upsert(
        Todo(
          id: 't3',
          title: '일상 1',
          category: Category.daily,
          createdAt: DateTime.utc(2026, 5, 28, 2),
          updatedAt: DateTime.utc(2026, 5, 28, 2),
        ),
      );

      expect(await db.categoriesDao.countTodosOfCategory('work'), 2);
      expect(await db.categoriesDao.countTodosOfCategory('daily'), 1);
      expect(await db.categoriesDao.countTodosOfCategory('idea'), 0);
    });

    test('watchAll 이 mutation 마다 emit', () async {
      // 첫 emit — 5 builtin.
      final first = await db.categoriesDao.watchAll().first;
      expect(first.length, 5);

      // 하나 delete + 하나 add 후 새 emit 확인.
      await db.categoriesDao.deleteById('idea');
      const fresh = Category(
        id: 'study',
        label: '공부',
        iconCodePoint: 0xe865,
        colorValue: 0xFF888888,
        sortOrder: 99,
        isBuiltin: false,
      );
      await db.categoriesDao.upsert(fresh);

      final next = await db.categoriesDao.watchAll().first;
      expect(next.length, 5);
      expect(next.any((c) => c.id == 'idea'), isFalse);
      expect(next.last.id, 'study');
    });
  });
}
