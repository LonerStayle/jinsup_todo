import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/data/local/app_database.dart';
import 'package:solo_todo/src/data/local/local_categories_repository.dart';
import 'package:solo_todo/src/data/local/local_groups_repository.dart';
import 'package:solo_todo/src/data/local/local_todo_repository.dart';
import 'package:solo_todo/src/data/remote/supabase_categories_api.dart';
import 'package:solo_todo/src/data/remote/supabase_groups_api.dart';
import 'package:solo_todo/src/data/remote/supabase_realtime_sync.dart';
import 'package:solo_todo/src/data/remote/supabase_todos_api.dart';
import 'package:solo_todo/src/data/syncing_todo_repository.dart';
import 'package:solo_todo/src/data/todo_repository.dart';
import 'package:solo_todo/src/domain/category.dart';
import 'package:solo_todo/src/domain/group.dart';
import 'package:solo_todo/src/domain/todo.dart';

void main() {
  test('Supabase 미설정 → supabaseRealtimeSyncProvider == null (활성화 안 됨)', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(supabaseRealtimeSyncProvider), isNull);
  });

  group('applyInsertOrUpdate / applyDelete — self-receive 무한 루프 방지', () {
    late AppDatabase db;
    late SyncingTodoRepository syncingRepo;
    late TodoRepository localOnly;
    late _FakeApi api;
    late SupabaseRealtimeSync sync;

    setUp(() {
      db = AppDatabase.memory();
      api = _FakeApi();
      syncingRepo = SyncingTodoRepository(
        local: db.todosDao,
        outbox: db.outboxDao,
        api: api,
        userIdGetter: () => 'u1',
      );
      localOnly = LocalTodoRepository(db.todosDao);
      sync = SupabaseRealtimeSync.forApplyOnly(
        api: api,
        localApply: localOnly,
        flushOutbox: () => syncingRepo.flushPending(),
        userId: 'u1',
        categoriesApi: _FakeCategoriesApi(),
        categoriesApply: LocalCategoriesRepository(db.categoriesDao),
        groupsApi: _FakeGroupsApi(),
        groupsApply: LocalGroupsRepository(db.groupsDao),
      );
    });

    tearDown(() async => db.close());

    Todo make({String id = 'a', bool done = false, DateTime? updatedAt}) {
      final t = updatedAt ?? DateTime.utc(2026, 5, 27, 9);
      return Todo(
        id: id,
        title: 'x',
        category: Category.daily,
        dueAt: null,
        doneAt: done ? t : null,
        createdAt: DateTime.utc(2026, 5, 27, 9),
        updatedAt: t,
        calendarEventId: null,
      );
    }

    test(
      '체크된 todo 의 self-receive payload 적용 → outbox 가 비어 있는 상태로 유지',
      () async {
        // 사용자 mutation 이 outbox 를 통해 이미 flush 된 상태를 가정.
        // 이제 self-broadcast 가 같은 row 를 다시 들고 옴.
        final mutated = make(done: true);

        // 사용자 mutation 으로 local 에는 이미 들어가 있음.
        await syncingRepo.upsert(mutated);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(await db.outboxDao.count(), 0); // flushPending 으로 비워짐

        // realtime self-receive 시 outbox 가 다시 enqueue 되면 안 됨.
        await sync.applyInsertOrUpdate(mutated);
        await sync.applyInsertOrUpdate(mutated); // 반복 broadcast 시뮬레이션

        expect(await db.outboxDao.count(), 0); // **핵심**: 절대 늘면 안 됨
        // local 은 그대로 done 상태 유지 (체크 풀림 X).
        final stored = await db.todosDao.getById('a');
        expect(stored?.doneAt, isNotNull);
      },
    );

    test('삭제 self-receive payload 적용 → outbox 비어 있음 + local 도 삭제 유지', () async {
      // 사용자가 todo 추가 후 삭제한 상태 가정 (outbox flush 까지 끝남).
      await syncingRepo.upsert(make(id: 'b'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await syncingRepo.deleteById('b');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(await db.outboxDao.count(), 0);
      expect(await db.todosDao.getById('b'), isNull);

      // realtime DELETE self-broadcast.
      await sync.applyDelete('b');
      await sync.applyDelete('b'); // 멱등

      // 핵심: 자기 자신의 delete 가 outbox 에 다시 들어가면 무한 delete loop.
      expect(await db.outboxDao.count(), 0);
      expect(await db.todosDao.getById('b'), isNull);
    });

    test('원격이 더 옛 updatedAt 인 stale payload → local 채택 (체크가 풀리지 않음)', () async {
      // 사용자가 빠르게 토글한 결과 local 은 done=false (최신 T2).
      // 그 사이 realtime 으로 옛 done=true (T1) payload 가 도착.
      final fresh = make(done: false, updatedAt: DateTime.utc(2026, 5, 27, 10));
      await db.todosDao.upsert(fresh);

      final stale = make(done: true, updatedAt: DateTime.utc(2026, 5, 27, 9));
      await sync.applyInsertOrUpdate(stale);

      final stored = await db.todosDao.getById('a');
      expect(
        stored?.doneAt,
        isNull,
        reason: 'stale 한 done=true 가 fresh done=false 를 덮으면 체크 풀림 발생',
      );
    });
  });

  group('categories / groups cross-device 동기화 — apply* 가 로컬 반영', () {
    late AppDatabase db;
    late SupabaseRealtimeSync sync;

    setUp(() {
      db = AppDatabase.memory();
      sync = SupabaseRealtimeSync.forApplyOnly(
        api: _FakeApi(),
        localApply: LocalTodoRepository(db.todosDao),
        flushOutbox: () async {},
        userId: 'u1',
        categoriesApi: _FakeCategoriesApi(),
        categoriesApply: LocalCategoriesRepository(db.categoriesDao),
        groupsApi: _FakeGroupsApi(),
        groupsApply: LocalGroupsRepository(db.groupsDao),
      );
    });

    tearDown(() async => db.close());

    Category cat({String id = 'c1', String label = '회사'}) => Category(
      id: id,
      label: label,
      iconCodePoint: Icons.work_outline.codePoint,
      colorValue: 0xFF2A66FF,
      sortOrder: 0,
    );

    Group grp({String id = 'g1', String label = '업무'}) =>
        Group(id: id, label: label, colorValue: 0xFF2A66FF);

    test('applyCategoryUpsert → 로컬 categories 에 반영', () async {
      await sync.applyCategoryUpsert(cat());
      final stored = await db.categoriesDao.getById('c1');
      expect(stored, isNotNull);
      expect(stored?.label, '회사');

      // upsert 멱등 + 갱신 반영.
      await sync.applyCategoryUpsert(cat(label: '회사(수정)'));
      final updated = await db.categoriesDao.getById('c1');
      expect(updated?.label, '회사(수정)');
    });

    test('applyCategoryDelete → 로컬에서 제거', () async {
      await sync.applyCategoryUpsert(cat());
      await sync.applyCategoryDelete('c1');
      expect(await db.categoriesDao.getById('c1'), isNull);
    });

    test('applyGroupUpsert → 로컬 groups 에 반영', () async {
      await sync.applyGroupUpsert(grp());
      final stored = await db.groupsDao.getById('g1');
      expect(stored, isNotNull);
      expect(stored?.label, '업무');
    });

    test('applyGroupDelete → 로컬에서 제거', () async {
      await sync.applyGroupUpsert(grp());
      await sync.applyGroupDelete('g1');
      expect(await db.groupsDao.getById('g1'), isNull);
    });
  });

  // 시작-동기화의 snapshot 재조정. fetchAll 은 "원격에 남아 있는" 행만 돌려주므로,
  // upsert-only 로는 (1) 다른 기기에서 삭제된 행이 로컬에 영원히 남고(증상②),
  // (2) 로컬 삭제 직후 원격에 아직 남아 있으면 snapshot 이 되살린다(증상①).
  // reconcile* 가 두 케이스를 모두 막는다.
  group('snapshot 재조정 — 삭제 전파 + 부활 방지', () {
    late AppDatabase db;
    late SupabaseRealtimeSync sync;

    setUp(() {
      db = AppDatabase.memory();
      sync = SupabaseRealtimeSync.forApplyOnly(
        api: _FakeApi(),
        localApply: LocalTodoRepository(db.todosDao),
        flushOutbox: () async {},
        userId: 'u1',
        categoriesApi: _FakeCategoriesApi(),
        categoriesApply: LocalCategoriesRepository(db.categoriesDao),
        groupsApi: _FakeGroupsApi(),
        groupsApply: LocalGroupsRepository(db.groupsDao),
      );
    });

    tearDown(() async => db.close());

    Todo todo({String id = 'a'}) => Todo(
      id: id,
      title: 'x',
      category: Category.daily,
      dueAt: null,
      doneAt: null,
      createdAt: DateTime.utc(2026, 5, 27, 9),
      updatedAt: DateTime.utc(2026, 5, 27, 9),
      calendarEventId: null,
    );

    Category cat({String id = 'work', String label = '회사 할일'}) => Category(
      id: id,
      label: label,
      iconCodePoint: Icons.work_outline.codePoint,
      colorValue: 0xFF2A66FF,
      sortOrder: 0,
    );

    Group grp({String id = 'g1', String label = '업무'}) =>
        Group(id: id, label: label, colorValue: 0xFF2A66FF);

    test('증상② — 원격 snapshot 에 없는 로컬 todo 는 제거(삭제 전파)', () async {
      await db.todosDao.upsert(todo(id: 'keep'));
      await db.todosDao.upsert(todo(id: 'gone')); // 다른 기기서 삭제됨
      await db.todosDao.upsert(todo(id: 'offline')); // 아직 push 안 한 신규

      await sync.reconcileTodos(
        [todo(id: 'keep')], // 원격엔 keep 만 남음
        localIds: {'keep', 'gone', 'offline'},
        pendingDeleteIds: {},
        pendingUpsertIds: {'offline'}, // 미push 신규 → 보존돼야 함
      );

      expect(await db.todosDao.getById('keep'), isNotNull);
      expect(await db.todosDao.getById('gone'), isNull, reason: '삭제 전파');
      expect(
        await db.todosDao.getById('offline'),
        isNotNull,
        reason: '미push 신규는 지우면 안 됨',
      );
    });

    test('증상① — 로컬 삭제 대기(pending delete)인 행은 snapshot 이 되살리지 않음', () async {
      // 로컬에선 이미 삭제됨(local 에 없음). 원격엔 아직 남아 outbox delete 대기 중.
      await sync.reconcileTodos(
        [todo(id: 'penddel')],
        localIds: {},
        pendingDeleteIds: {'penddel'},
        pendingUpsertIds: {},
      );
      expect(
        await db.todosDao.getById('penddel'),
        isNull,
        reason: '삭제 대기 행을 upsert 로 되살리면 부활 버그',
      );
    });

    test('빈 원격 snapshot 으로는 로컬을 지우지 않음(일시 fetch 실패/부트스트랩 보호)', () async {
      await db.todosDao.upsert(todo(id: 'a'));
      await sync.reconcileTodos(
        [],
        localIds: {'a'},
        pendingDeleteIds: {},
        pendingUpsertIds: {},
      );
      expect(
        await db.todosDao.getById('a'),
        isNotNull,
        reason: '빈 snapshot 으로 전체 삭제하면 데이터 유실',
      );
    });

    test('증상①② — 카테고리: 원격에 없는 builtin 제거 + pending delete 부활 방지', () async {
      await db.categoriesDao.upsert(cat(id: 'work', label: '회사 할일'));
      await db.categoriesDao.upsert(cat(id: 'daily', label: '일상'));

      await sync.reconcileCategories(
        [cat(id: 'daily', label: '일상')], // work 는 다른 기기서 삭제됨
        localIds: {'work', 'daily'},
        pendingDeleteIds: {},
        pendingUpsertIds: {},
      );

      expect(
        await db.categoriesDao.getById('work'),
        isNull,
        reason: '그룹없는 회사할일이 되살아나면 안 됨',
      );
      expect(await db.categoriesDao.getById('daily'), isNotNull);
    });

    test('카테고리: 로컬 삭제 대기(pending cat-delete)는 snapshot 이 되살리지 않음', () async {
      // builtin seed 와 겹치지 않는 커스텀 카테고리로 검증(memory() 가 5 builtin 을 seed).
      await sync.reconcileCategories(
        [cat(id: 'c-custom', label: '커스텀')],
        localIds: {},
        pendingDeleteIds: {'c-custom'},
        pendingUpsertIds: {},
      );
      expect(await db.categoriesDao.getById('c-custom'), isNull);
    });

    test('그룹: 원격에 없는 로컬 그룹 제거 + 미push 신규 보존', () async {
      await db.groupsDao.upsert(grp(id: 'keep'));
      await db.groupsDao.upsert(grp(id: 'gone'));
      await db.groupsDao.upsert(grp(id: 'offline'));

      await sync.reconcileGroups(
        [grp(id: 'keep')],
        localIds: {'keep', 'gone', 'offline'},
        pendingDeleteIds: {},
        pendingUpsertIds: {'offline'},
      );

      expect(await db.groupsDao.getById('keep'), isNotNull);
      expect(await db.groupsDao.getById('gone'), isNull);
      expect(await db.groupsDao.getById('offline'), isNotNull);
    });
  });
}

class _FakeApi implements RemoteTodosApi {
  final List<Todo> remoteStore = [];

  @override
  Future<List<Todo>> fetchAll(String userId) async => List.of(remoteStore);

  @override
  Todo todoFromRow(Map<String, dynamic> row) => throw UnimplementedError();

  @override
  Future<void> upsert(Todo todo, String userId) async {
    remoteStore.removeWhere((r) => r.id == todo.id);
    remoteStore.add(todo);
  }

  @override
  Future<void> deleteById(String id, String userId) async {
    remoteStore.removeWhere((r) => r.id == id);
  }
}

class _FakeCategoriesApi implements RemoteCategoriesApi {
  final List<Category> remoteStore = [];

  @override
  Future<List<Category>> fetchAll(String userId) async => List.of(remoteStore);

  @override
  Category categoryFromRow(Map<String, dynamic> row) =>
      throw UnimplementedError();

  @override
  Future<void> upsert(Category category, String userId) async {
    remoteStore.removeWhere((r) => r.id == category.id);
    remoteStore.add(category);
  }

  @override
  Future<void> deleteById(String id, String userId) async {
    remoteStore.removeWhere((r) => r.id == id);
  }
}

class _FakeGroupsApi implements RemoteGroupsApi {
  final List<Group> remoteStore = [];

  @override
  Future<List<Group>> fetchAll(String userId) async => List.of(remoteStore);

  @override
  Group groupFromRow(Map<String, dynamic> row) => throw UnimplementedError();

  @override
  Future<void> upsert(Group group, String userId) async {
    remoteStore.removeWhere((r) => r.id == group.id);
    remoteStore.add(group);
  }

  @override
  Future<void> deleteById(String id, String userId) async {
    remoteStore.removeWhere((r) => r.id == id);
  }
}
