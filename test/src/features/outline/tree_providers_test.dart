import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/data/local/app_database.dart';
import 'package:solo_todo/src/data/providers.dart';
import 'package:solo_todo/src/domain/category.dart';
import 'package:solo_todo/src/domain/todo.dart';
import 'package:solo_todo/src/features/outline/tree_providers.dart';

void main() {
  /// 결정적 시점.
  final t0 = DateTime.utc(2026, 5, 27, 9);
  Todo make({
    required String id,
    String title = 't',
    Category category = Category.daily,
    String? parentId,
    TodoType type = TodoType.task,
    DateTime? doneAt,
    int sortOrder = 0,
    DateTime? createdAt,
  }) {
    final c = createdAt ?? t0;
    return Todo(
      id: id,
      title: title,
      category: category,
      dueAt: null,
      doneAt: doneAt,
      createdAt: c,
      updatedAt: c,
      calendarEventId: null,
      parentId: parentId,
      type: type,
      sortOrder: sortOrder,
    );
  }

  group('TodosDao tree queries', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.memory());
    tearDown(() async => db.close());

    test('watchChildrenOf — 같은 parentId 만 emit, sortOrder asc 정렬', () async {
      await db.todosDao.upsert(make(id: 'p', title: '프로젝트'));
      // 자식 — 의도적으로 sortOrder 역순 insert.
      await db.todosDao.upsert(make(id: 'c2', parentId: 'p', sortOrder: 2));
      await db.todosDao.upsert(make(id: 'c0', parentId: 'p', sortOrder: 0));
      await db.todosDao.upsert(make(id: 'c1', parentId: 'p', sortOrder: 1));
      // 다른 parent — 결과에 포함되면 안 됨.
      await db.todosDao.upsert(make(id: 'other', parentId: 'q'));
      // root — 결과에 포함되면 안 됨.
      await db.todosDao.upsert(make(id: 'root-x'));

      final children = await db.todosDao.watchChildrenOf('p').first;
      expect(children.map((t) => t.id), ['c0', 'c1', 'c2']);
    });

    test('watchRootsOfCategory — parent_id IS NULL + category 일치만', () async {
      // root (parent 없음).
      await db.todosDao.upsert(make(id: 'r1', category: Category.work));
      await db.todosDao.upsert(make(id: 'r2', category: Category.work));
      // 다른 카테고리 root.
      await db.todosDao.upsert(make(id: 'd', category: Category.daily));
      // 자식 (parent 있음) — 같은 카테고리지만 root 아니므로 제외.
      await db.todosDao.upsert(
        make(id: 'child', category: Category.work, parentId: 'r1'),
      );

      final workRoots = await db.todosDao
          .watchRootsOfCategory(Category.work)
          .first;
      expect(workRoots.map((t) => t.id).toSet(), {'r1', 'r2'});
    });

    test('watchRootsOfCategory — 빈 카테고리는 빈 list', () async {
      expect(
        await db.todosDao.watchRootsOfCategory(Category.idea).first,
        isEmpty,
      );
    });
  });

  group('computeSubtreeProgress', () {
    test('자식 없음 — (0, 0), ratio null', () {
      final root = make(id: 'r');
      final progress = computeSubtreeProgress(root, [root]);
      expect(progress, const SubtreeProgress(doneCount: 0, taskCount: 0));
      expect(progress.ratio, isNull);
    });

    test('자식 task 3, done 1 — (1, 3)', () {
      final root = make(id: 'r');
      final all = [
        root,
        make(id: 'c1', parentId: 'r'),
        make(id: 'c2', parentId: 'r', doneAt: t0.add(const Duration(hours: 1))),
        make(id: 'c3', parentId: 'r'),
      ];
      final p = computeSubtreeProgress(root, all);
      expect(p, const SubtreeProgress(doneCount: 1, taskCount: 3));
      expect(p.ratio, closeTo(1 / 3, 1e-9));
    });

    test('note 는 분모/분자 모두 제외', () {
      final root = make(id: 'r');
      final all = [
        root,
        make(id: 'task1', parentId: 'r'),
        make(id: 'task2', parentId: 'r', doneAt: t0),
        make(id: 'note1', parentId: 'r', type: TodoType.note),
        make(id: 'note2', parentId: 'r', type: TodoType.note),
      ];
      final p = computeSubtreeProgress(root, all);
      expect(p.taskCount, 2);
      expect(p.doneCount, 1);
    });

    test('자손 재귀 walk — 손자까지 카운트', () {
      final root = make(id: 'r');
      final all = [
        root,
        make(id: 'p1', parentId: 'r'), // 자식 (폴더 역할)
        make(id: 'p2', parentId: 'r'),
        make(id: 'g1', parentId: 'p1', doneAt: t0), // 손자 — done
        make(id: 'g2', parentId: 'p1'), // 손자
        make(id: 'g3', parentId: 'p2', doneAt: t0), // 손자 — done
        // 손자 안 note 도 분모 제외.
        make(id: 'g4', parentId: 'p2', type: TodoType.note),
      ];
      final p = computeSubtreeProgress(root, all);
      // p1, p2 (자식 폴더) 도 task 라서 분모에 포함. + g1, g2, g3 도. g4 는 note 제외.
      expect(p.taskCount, 5);
      expect(p.doneCount, 2);
    });

    test('root 자기 자신은 카운트 X', () {
      // 자기 자신이 done 이어도 자기 카운트는 안 됨.
      final root = make(id: 'r', doneAt: t0);
      final all = [root, make(id: 'c1', parentId: 'r')];
      final p = computeSubtreeProgress(root, all);
      expect(p, const SubtreeProgress(doneCount: 0, taskCount: 1));
    });

    test('관계 없는 다른 트리는 포함 X', () {
      final root = make(id: 'r');
      final all = [
        root,
        make(id: 'c1', parentId: 'r'),
        // 다른 root + 자식 — 관계 없음.
        make(id: 'other-root'),
        make(id: 'other-child', parentId: 'other-root'),
      ];
      final p = computeSubtreeProgress(root, all);
      expect(p, const SubtreeProgress(doneCount: 0, taskCount: 1));
    });

    test('SubtreeProgress equality 와 toString', () {
      const a = SubtreeProgress(doneCount: 2, taskCount: 5);
      const b = SubtreeProgress(doneCount: 2, taskCount: 5);
      const c = SubtreeProgress(doneCount: 3, taskCount: 5);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
      expect(a.toString(), 'SubtreeProgress(2/5)');
    });
  });

  group('riverpod providers', () {
    test('childrenOfProvider — DAO stream 그대로 노출', () async {
      final db = AppDatabase.memory();
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });

      await db.todosDao.upsert(make(id: 'p'));
      await db.todosDao.upsert(make(id: 'c1', parentId: 'p'));
      await db.todosDao.upsert(make(id: 'c2', parentId: 'p', sortOrder: 1));

      container.listen(childrenOfProvider('p'), (_, _) {});
      await Future<void>.delayed(Duration.zero);

      final value = container.read(childrenOfProvider('p')).requireValue;
      expect(value.map((t) => t.id), ['c1', 'c2']);
    });

    test('rootsOfCategoryProvider — 카테고리별 root 만 emit', () async {
      final db = AppDatabase.memory();
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });

      await db.todosDao.upsert(make(id: 'r1', category: Category.work));
      await db.todosDao.upsert(make(id: 'd', category: Category.daily));

      container.listen(rootsOfCategoryProvider(Category.work), (_, _) {});
      await Future<void>.delayed(Duration.zero);

      final value = container
          .read(rootsOfCategoryProvider(Category.work))
          .requireValue;
      expect(value.map((t) => t.id), ['r1']);
    });
  });
}
