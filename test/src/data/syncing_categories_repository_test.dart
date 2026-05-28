import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/data/local/app_database.dart';
import 'package:solo_todo/src/data/remote/supabase_categories_api.dart';
import 'package:solo_todo/src/data/syncing_categories_repository.dart';
import 'package:solo_todo/src/domain/category.dart';

void main() {
  late AppDatabase db;
  late _FakeApi api;
  late SyncingCategoriesRepository repo;
  String? userId;

  setUp(() {
    db = AppDatabase.memory();
    api = _FakeApi();
    userId = 'u1';
    repo = SyncingCategoriesRepository(
      local: db.categoriesDao,
      outbox: db.outboxDao,
      api: api,
      userIdGetter: () => userId,
    );
  });

  tearDown(() async => db.close());

  const custom = Category(
    id: 'study',
    label: '공부',
    iconCodePoint: 0xe865,
    colorValue: 0xFF888888,
    sortOrder: 99,
    isBuiltin: false,
  );

  test('upsert — local 저장 + outbox enqueue + 즉시 push 성공 시 outbox 비움', () async {
    await repo.upsert(custom);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(await db.categoriesDao.getById('study'), isNotNull);
    expect(api.upsertCalls.single.c.id, 'study');
    expect(api.upsertCalls.single.userId, 'u1');
    expect(await db.outboxDao.count(), 0);
  });

  test('deleteById — local 삭제 + outbox enqueue + 원격 delete 호출', () async {
    // builtin 'idea' 가 onCreate 로 이미 있으니 그걸 삭제.
    await repo.deleteById('idea');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(await db.categoriesDao.getById('idea'), isNull);
    expect(api.deleteCalls, [('idea', 'u1')]);
    expect(await db.outboxDao.count(), 0);
  });

  test('원격 fail 시 outbox 에 남음, flushPending 재시도 성공 시 비움', () async {
    api.failAll = true;
    await repo.upsert(custom);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(await db.outboxDao.count(), 1);
    expect(await db.categoriesDao.getById('study'), isNotNull); // local 유지

    api.failAll = false;
    await repo.flushPending();
    expect(await db.outboxDao.count(), 0);
    expect(api.upsertCalls.last.c.id, 'study');
  });

  test('userId null (미인증) → outbox 에 남고 push 호출 안 됨', () async {
    userId = null;
    await repo.upsert(custom);
    await Future<void>.delayed(Duration.zero);

    expect(await db.outboxDao.count(), 1);
    expect(api.upsertCalls, isEmpty);

    // 다시 인증 → flushPending 호출 시 push.
    userId = 'u1';
    await repo.flushPending();
    expect(await db.outboxDao.count(), 0);
    expect(api.upsertCalls.single.c.id, 'study');
  });

  test('다른 kind (todos upsert) 와 같은 outbox 에 있어도 자기 cat-* 만 처리', () async {
    // 직접 todos 의 outbox row 를 enqueue — categories repo 가 건드리면 안 됨.
    await db.outboxDao.enqueue(
      OutboxRow(
        id: 'todo-entry-1',
        kind: 'upsert',
        todoId: 't1',
        payload: '{"id":"t1"}', // 매핑 실패해도 categories repo 는 skip 이라 무관
        createdAt: DateTime.utc(2026, 5, 28),
      ),
    );

    await repo.upsert(custom);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    // todos entry 는 그대로, categories entry 만 처리됨.
    expect(await db.outboxDao.count(), 1);
    final remaining = await db.outboxDao.allOrdered();
    expect(remaining.single.id, 'todo-entry-1');
    expect(remaining.single.kind, 'upsert');
  });

  test('upsert payload round-trip — push 시 같은 Category 가 api 로 도달', () async {
    api.failAll = true;
    await repo.upsert(custom);
    await Future<void>.delayed(Duration.zero);

    api.failAll = false;
    await repo.flushPending();
    final pushed = api.upsertCalls.single.c;
    expect(pushed.id, 'study');
    expect(pushed.label, '공부');
    expect(pushed.iconCodePoint, 0xe865);
    expect(pushed.colorValue, 0xFF888888);
    expect(pushed.sortOrder, 99);
    expect(pushed.isBuiltin, isFalse);
  });
}

class _FakeApi implements RemoteCategoriesApi {
  final List<({Category c, String userId})> upsertCalls = [];
  final List<(String, String)> deleteCalls = [];
  bool failAll = false;

  @override
  Future<void> upsert(Category c, String userId) async {
    if (failAll) throw StateError('simulated network error');
    upsertCalls.add((c: c, userId: userId));
  }

  @override
  Future<void> deleteById(String id, String userId) async {
    if (failAll) throw StateError('simulated network error');
    deleteCalls.add((id, userId));
  }

  @override
  Future<List<Category>> fetchAll(String userId) async => const [];

  @override
  Category categoryFromRow(Map<String, dynamic> row) {
    // fake — 단위 테스트에서는 호출 안 됨.
    return Category.daily;
  }
}
