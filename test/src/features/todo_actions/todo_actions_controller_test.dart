import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/data/local/app_database.dart';
import 'package:solo_todo/src/data/local/local_todo_repository.dart';
import 'package:solo_todo/src/domain/category.dart';
import 'package:solo_todo/src/domain/todo.dart';
import 'package:solo_todo/src/features/outline/tree_providers.dart';
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

  test('delete: row 가 사라짐', () async {
    final original = seed();
    await repo.upsert(original);

    await controller.delete(original);

    expect(await repo.getById('a'), isNull);
  });

  test('restore: delete 후 복원 시 동일 id + updatedAt 보존', () async {
    final original = seed(doneAt: DateTime.utc(2026, 5, 27, 10));
    await repo.upsert(original);

    await controller.delete(original);
    expect(await repo.getById('a'), isNull);

    await controller.restore(original);
    expect(await repo.getById('a'), original);
  });

  group('Task B — sortOrder 불변식 / bump / reorder', () {
    Todo make(String id, {int sortOrder = 0, DateTime? doneAt}) => Todo(
      id: id,
      title: id,
      category: Category.work,
      dueAt: null,
      doneAt: doneAt,
      createdAt: created,
      updatedAt: created,
      calendarEventId: null,
      sortOrder: sortOrder,
    );

    test('toggle 은 sortOrder 를 바꾸지 않는다 (체크해도 자리 유지)', () async {
      final t = make('a', sortOrder: 5);
      await repo.upsert(t);

      final later = DateTime.utc(2026, 5, 27, 12);
      controller = TodoActionsController(repo, () => later);
      final toggled = await controller.toggle(t);

      expect(toggled.sortOrder, 5, reason: '체크 시 sortOrder 불변');
      expect((await repo.getById('a'))!.sortOrder, 5);
    });

    test('update (시트 편집) 는 sortOrder 를 min(형제)-1 로 bump (맨 위)', () async {
      await repo.upsert(make('a', sortOrder: 0));
      await repo.upsert(make('b', sortOrder: 1));
      await repo.upsert(make('c', sortOrder: 2));

      // c 를 편집 → 맨 위로 (min 0 - 1 = -1).
      final edited = await controller.update(
        make('c', sortOrder: 2).copyWith(title: 'c-edited'),
      );
      expect(edited.sortOrder, -1);

      final list = await repo.watchByCategory(Category.work).first;
      expect(list.map((t) => t.id).first, 'c', reason: '편집한 항목이 맨 위로');
    });

    test('reorderSiblings — 새 순서대로 연속 sortOrder 재부여 (min 기준)', () async {
      // 시각 순서 [a(0), b(1), c(2)] 에서 c 를 맨 앞으로.
      final a = make('a', sortOrder: 0);
      final b = make('b', sortOrder: 1);
      final c = make('c', sortOrder: 2);
      for (final t in [a, b, c]) {
        await repo.upsert(t);
      }

      // c(index 2) → index 0 으로.
      await controller.reorderSiblings([a, b, c], 2, 0);

      final list = await repo.watchByCategory(Category.work).first;
      expect(list.map((t) => t.id).toList(), ['c', 'a', 'b']);
      // base = min(0) → c=0, a=1, b=2.
      expect((await repo.getById('c'))!.sortOrder, 0);
      expect((await repo.getById('a'))!.sortOrder, 1);
      expect((await repo.getById('b'))!.sortOrder, 2);
    });

    test('reorderSiblings — 변화 없는 이동(target==old)은 no-op', () async {
      final a = make('a', sortOrder: 0);
      final b = make('b', sortOrder: 1);
      await repo.upsert(a);
      await repo.upsert(b);

      // ReorderableList 시맨틱: index 0 → newIndex 0 → 보정 후 동일.
      await controller.reorderSiblings([a, b], 0, 0);

      expect((await repo.getById('a'))!.sortOrder, 0);
      expect((await repo.getById('b'))!.sortOrder, 1);
    });
  });

  group('§14-C — 타입 전환 시 자식 보존 (메모↔할일 왕복)', () {
    Todo node(
      String id, {
      String? parentId,
      TodoType type = TodoType.task,
      DateTime? doneAt,
    }) => Todo(
      id: id,
      title: id,
      category: Category.work,
      dueAt: null,
      doneAt: doneAt,
      createdAt: created,
      updatedAt: created,
      calendarEventId: null,
      parentId: parentId,
      type: type,
    );

    test('부모 task→note 전환 — 자식 parentId / 서브트리 진척 보존', () async {
      await repo.upsert(node('p'));
      await repo.upsert(node('c1', parentId: 'p', doneAt: created));
      await repo.upsert(node('c2', parentId: 'p'));

      // id 동일하게 type 만 note 로 전환.
      final asNote = (await repo.getById(
        'p',
      ))!.copyWith(type: TodoType.note, doneAt: null);
      await controller.update(asNote);

      // 자식 parentId 는 부모 id 를 그대로 가리킨다(전환은 id 불변).
      expect((await repo.getById('c1'))!.parentId, 'p');
      expect((await repo.getById('c2'))!.parentId, 'p');
      expect((await repo.getById('p'))!.type, TodoType.note);

      // 헤딩이 된 부모의 서브트리 진척 — task 자식 2 중 1 done.
      final all = await repo.watchByCategory(Category.work).first;
      final progress = computeSubtreeProgress((await repo.getById('p'))!, all);
      expect(progress, const SubtreeProgress(doneCount: 1, taskCount: 2));
    });

    test('부모 note→task 전환 — 자식 보존 (왕복 정합)', () async {
      await repo.upsert(node('p', type: TodoType.note));
      await repo.upsert(node('c1', parentId: 'p'));

      final asTask = (await repo.getById('p'))!.copyWith(type: TodoType.task);
      await controller.update(asTask);

      expect((await repo.getById('c1'))!.parentId, 'p');
      expect((await repo.getById('p'))!.type, TodoType.task);
    });
  });
}
