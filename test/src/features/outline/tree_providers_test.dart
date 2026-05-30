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

    // §14-A — 메모(note)가 "섹션 헤딩"으로 root 인 경우. root 타입과 무관하게
    // 자식만 walk 하므로 task 자손 진척률이 정확히 계산되어야 한다.
    test('note 헤딩 root — task 자식 [done/total] 정확', () {
      final noteRoot = make(id: 'h', type: TodoType.note);
      final all = [
        noteRoot,
        make(id: 't1', parentId: 'h', doneAt: t0),
        make(id: 't2', parentId: 'h'),
        make(id: 't3', parentId: 'h'),
      ];
      final p = computeSubtreeProgress(noteRoot, all);
      expect(p, const SubtreeProgress(doneCount: 1, taskCount: 3));
    });

    test('note 헤딩 root — 손자까지 누적 + 자손 note 제외', () {
      final noteRoot = make(id: 'h', type: TodoType.note);
      final all = [
        noteRoot,
        make(id: 'sub', parentId: 'h'), // task 자식(폴더)
        make(id: 'g1', parentId: 'sub', doneAt: t0), // 손자 task done
        make(id: 'g2', parentId: 'sub'), // 손자 task
        make(id: 'subnote', parentId: 'h', type: TodoType.note), // 자손 note 제외
        make(id: 'gn', parentId: 'subnote'), // note 아래 task 도 walk 로 카운트
      ];
      final p = computeSubtreeProgress(noteRoot, all);
      // sub, g1, g2, gn = task 4 / done 1. subnote(note) 제외.
      expect(p, const SubtreeProgress(doneCount: 1, taskCount: 4));
    });

    test('note 헤딩 root — note 자식만 있으면 (0,0)', () {
      final noteRoot = make(id: 'h', type: TodoType.note);
      final all = [
        noteRoot,
        make(id: 'cn', parentId: 'h', type: TodoType.note),
      ];
      final p = computeSubtreeProgress(noteRoot, all);
      expect(p, const SubtreeProgress(doneCount: 0, taskCount: 0));
      expect(p.ratio, isNull);
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

  group('computeTodoPath', () {
    test('parentId null — 빈 path (root)', () {
      final root = make(id: 'r');
      expect(computeTodoPath(root, [root]), isEmpty);
    });

    test('직속 부모만 (depth 1) — path = [parent]', () {
      final parent = make(id: 'p', title: 'JS슈퍼');
      final child = make(id: 'c', parentId: 'p');
      final path = computeTodoPath(child, [parent, child]);
      expect(path.map((t) => t.title), ['JS슈퍼']);
    });

    test('손자 — path = [root, 직속부모]', () {
      final root = make(id: 'r', title: '개인 TODO');
      final mid = make(id: 'm', title: 'JS슈퍼', parentId: 'r');
      final leaf = make(id: 'l', parentId: 'm');
      final path = computeTodoPath(leaf, [root, mid, leaf]);
      expect(path.map((t) => t.title), ['개인 TODO', 'JS슈퍼']);
    });

    test('parent_id 가 list 에 없음 (dangling) → 거기서 중단', () {
      // 동기화 race 또는 옛 데이터에서 dangling 가능.
      final orphan = make(id: 'x', parentId: 'ghost');
      final path = computeTodoPath(orphan, [orphan]);
      expect(path, isEmpty);
    });

    test('사이클 (자기 자신을 부모로) → 무한 loop 없이 중단', () {
      final self = make(id: 's', parentId: 's');
      final path = computeTodoPath(self, [self]);
      expect(path, isEmpty);
    });

    test('2 노드 사이클 (a→b, b→a) → 한 번만 traverse 후 중단', () {
      // 데이터 손상 케이스. visited set 이 무한 loop 방지.
      final a = make(id: 'a', parentId: 'b');
      final b = make(id: 'b', parentId: 'a');
      final path = computeTodoPath(a, [a, b]);
      // 한 번 b 까지만 가고 a 재방문 시 visited 중단.
      expect(path.length, 1);
      expect(path.first.id, 'b');
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
