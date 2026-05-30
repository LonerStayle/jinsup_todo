import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/data/local/app_database.dart';
import 'package:solo_todo/src/data/local/local_todo_repository.dart';
import 'package:solo_todo/src/domain/category.dart';
import 'package:solo_todo/src/domain/todo.dart';
import 'package:solo_todo/src/features/todo_actions/todo_actions_controller.dart';

/// 작업 1 — "할 일 카테고리 편집이 저장 후 원래대로 돌아온다" 결판 테스트.
///
/// 데이터 계층(in-memory AppDatabase + LocalTodoRepository + TodosDao)에서 root
/// todo 의 category 를 A → B 로 바꿨을 때:
///   1. watchRootsOfCategory(A) 에서 사라지고 watchRootsOfCategory(B) 에 나타나는지
///   2. TodoActions.update 가 category 를 보존하는지 (sortOrder bump 와 함께)
/// 를 검증한다. 통과하면 데이터 계층은 정상 → 증상은 환경(옛 빌드/중복 인스턴스) 의심.
void main() {
  late AppDatabase db;
  late LocalTodoRepository repo;

  final created = DateTime.utc(2026, 5, 28, 9, 0);

  // 그룹이 다른 두 사용자 카테고리 (대표님 증상의 '일상' → '코기토' 재현).
  const catA = Category(
    id: 'daily',
    label: '일상',
    iconCodePoint: 0xf107,
    colorValue: 0xFF10B981,
    sortOrder: 2,
    isBuiltin: true,
  );
  const catB = Category(
    id: 'cogito',
    label: '코기토',
    iconCodePoint: 0xe176,
    colorValue: 0xFF8B5CF6,
    sortOrder: 9,
    groupId: 'group-x',
  );

  setUp(() {
    db = AppDatabase.memory();
    repo = LocalTodoRepository(db.todosDao);
  });

  tearDown(() async => db.close());

  Todo root({required Category category, int sortOrder = 0}) => Todo(
    id: 'r1',
    title: '장보기',
    category: category,
    dueAt: null,
    doneAt: null,
    createdAt: created,
    updatedAt: created,
    calendarEventId: null,
    sortOrder: sortOrder,
  );

  test(
    'upsert 로 category A→B 변경 → watchRootsOfCategory(A) 에서 사라지고 (B) 에 나타남',
    () async {
      await repo.upsert(root(category: catA));

      expect(
        (await db.todosDao.watchRootsOfCategory(catA).first).map((t) => t.id),
        ['r1'],
        reason: 'A 에 처음 들어있어야',
      );
      expect(
        await db.todosDao.watchRootsOfCategory(catB).first,
        isEmpty,
        reason: 'B 는 비어 있어야',
      );

      // category 만 B 로 바꿔 같은 id 로 upsert (덮어쓰기).
      await repo.upsert(root(category: catB));

      expect(
        await db.todosDao.watchRootsOfCategory(catA).first,
        isEmpty,
        reason: 'A 에서 사라져야',
      );
      expect(
        (await db.todosDao.watchRootsOfCategory(catB).first).map((t) => t.id),
        ['r1'],
        reason: 'B 로 이동해야',
      );

      // 영속된 row 의 category 도 실제 B.
      expect((await repo.getById('r1'))!.category.id, 'cogito');
    },
  );

  test(
    'TodoActions.update 는 새 category 를 보존한다 (sortOrder bump 와 함께)',
    () async {
      await repo.upsert(root(category: catA, sortOrder: 0));
      final controller = TodoActionsController(repo, () => created);

      // 시트 편집 시뮬레이션 — category 를 B 로 바꾼 Todo 를 update 에 넘김.
      final edited = root(
        category: catA,
        sortOrder: 0,
      ).copyWith(category: catB);
      final result = await controller.update(edited);

      expect(result.category.id, 'cogito', reason: 'update 가 category 를 보존');
      // B 형제가 자기뿐 → minSibling(B) == null → sortOrder 보존값 - 1.
      expect(result.sortOrder, -1, reason: 'min(형제)-1 bump');

      final fromDb = await repo.getById('r1');
      expect(fromDb!.category.id, 'cogito', reason: 'DB 에 B 로 영속');
      expect(
        await db.todosDao.watchRootsOfCategory(catA).first,
        isEmpty,
        reason: 'update 후 A 에서 사라져야',
      );
      expect(
        (await db.todosDao.watchRootsOfCategory(catB).first).single.id,
        'r1',
        reason: 'update 후 B 에 나타나야',
      );
    },
  );
}
