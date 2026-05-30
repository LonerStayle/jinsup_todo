import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/data/local/app_database.dart';
import 'package:solo_todo/src/data/local/local_categories_repository.dart';
import 'package:solo_todo/src/domain/category.dart';
import 'package:solo_todo/src/domain/policies/category_delete_policy.dart';
import 'package:solo_todo/src/domain/todo.dart';
import 'package:solo_todo/src/features/category/categories_controller.dart';

/// CategoriesController 검증 — in-memory DB 기반.
///
/// onCreate 가 5 builtin 을 seed 하므로 baseline = builtin 5종.
/// Controller 는 [CategoriesRepository] 의존 → 단위 테스트에서는
/// [LocalCategoriesRepository] (Drift DAO wrap) 사용.
void main() {
  group('CategoriesController', () {
    late AppDatabase db;
    late CategoriesController controller;

    setUp(() async {
      db = AppDatabase.memory();
      controller = CategoriesController(
        LocalCategoriesRepository(db.categoriesDao),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('add — 새 카테고리 추가 + watchAll 에 반영', () async {
      const fresh = Category(
        id: 'study',
        label: '공부',
        iconCodePoint: 0xe865,
        colorValue: 0xFF888888,
        sortOrder: 99,
        isBuiltin: false,
      );
      await controller.add(fresh);

      final list = await db.categoriesDao.watchAll().first;
      expect(list.length, 6);
      expect(list.any((c) => c.id == 'study'), isTrue);
    });

    test('delete — todoCount 0 일 때 ok + 실제 delete 됨', () async {
      // 'idea' 카테고리에 todo 가 없는 상태에서 delete.
      final result = await controller.delete('idea');
      expect(result, const DeleteCheck.ok());

      final list = await db.categoriesDao.watchAll().first;
      expect(list.length, 4);
      expect(list.any((c) => c.id == 'idea'), isFalse);
    });

    test(
      'delete — todoCount > 0 이면 blocked + todos 보존 + categories 도 보존',
      () async {
        // 'work' 카테고리에 todos 2건 추가.
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

        final result = await controller.delete('work');
        expect(result, const DeleteCheck.blockedByTodos(2));

        // todos 그대로 유지.
        expect(await db.todosDao.getById('t1'), isNotNull);
        expect(await db.todosDao.getById('t2'), isNotNull);

        // categories 도 그대로 (5건 유지).
        final list = await db.categoriesDao.watchAll().first;
        expect(list.length, 5);
        expect(list.any((c) => c.id == 'work'), isTrue);
      },
    );

    test('delete — 이미 존재하지 않는 id 면 idempotent ok 반환', () async {
      final result = await controller.delete('ghost-id-not-exist');
      expect(result, const DeleteCheck.ok());

      // baseline 5건 그대로.
      final list = await db.categoriesDao.watchAll().first;
      expect(list.length, 5);
    });

    test('builtin (work) 도 삭제 가능 — todos 0건이면 ok + 실제 delete', () async {
      // work 에 todo 없음 (baseline 그대로) — builtin 이라도 차단 안 됨.
      final result = await controller.delete('work');
      expect(result, const DeleteCheck.ok());

      final list = await db.categoriesDao.watchAll().first;
      expect(list.length, 4);
      expect(list.any((c) => c.id == 'work'), isFalse);
    });

    group('작업 2 (K) — reorderInGroup', () {
      // 같은 그룹의 카테고리 3종 (sortOrder 10/11/12).
      Category cat(String id, int sortOrder) => Category(
        id: id,
        label: id,
        iconCodePoint: 0xe865,
        colorValue: 0xFF888888,
        sortOrder: sortOrder,
        groupId: 'g1',
      );

      test('맨 아래 항목을 맨 위로 → 연속 sortOrder 재부여 (min 기준)', () async {
        final a = cat('a', 10);
        final b = cat('b', 11);
        final c = cat('c', 12);
        for (final x in [a, b, c]) {
          await controller.add(x);
        }

        // 시각 순서 [a,b,c] 에서 c(index 2) → index 0 으로.
        await controller.reorderInGroup([a, b, c], 2, 0);

        Future<int> orderOf(String id) async =>
            (await db.categoriesDao.getById(id))!.sortOrder;
        // base = min(10) → c=10, a=11, b=12.
        expect(await orderOf('c'), 10);
        expect(await orderOf('a'), 11);
        expect(await orderOf('b'), 12);

        // groupId 는 보존.
        expect((await db.categoriesDao.getById('c'))!.groupId, 'g1');
      });

      test('변화 없는 이동(target==old)은 no-op', () async {
        final a = cat('a', 10);
        final b = cat('b', 11);
        await controller.add(a);
        await controller.add(b);

        await controller.reorderInGroup([a, b], 0, 0);

        expect((await db.categoriesDao.getById('a'))!.sortOrder, 10);
        expect((await db.categoriesDao.getById('b'))!.sortOrder, 11);
      });
    });
  });
}
