import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/data/local/app_database.dart';
import 'package:solo_todo/src/data/local/local_todo_repository.dart';
import 'package:solo_todo/src/data/remote/supabase_realtime_sync.dart';
import 'package:solo_todo/src/data/remote/supabase_todos_api.dart';
import 'package:solo_todo/src/data/syncing_todo_repository.dart';
import 'package:solo_todo/src/data/todo_repository.dart';
import 'package:solo_todo/src/domain/category.dart';
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
