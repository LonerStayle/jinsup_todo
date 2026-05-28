import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/data/local/app_database.dart';
import 'package:solo_todo/src/data/remote/supabase_todos_api.dart';
import 'package:solo_todo/src/data/syncing_todo_repository.dart';
import 'package:solo_todo/src/domain/category.dart';
import 'package:solo_todo/src/domain/todo.dart';

void main() {
  late AppDatabase db;
  late _FakeApi api;
  late SyncingTodoRepository repo;
  String? userId;

  setUp(() {
    db = AppDatabase.memory();
    api = _FakeApi();
    userId = 'u1';
    repo = SyncingTodoRepository(
      local: db.todosDao,
      outbox: db.outboxDao,
      api: api,
      userIdGetter: () => userId,
    );
  });

  tearDown(() async => db.close());

  Todo make({String id = 'a', String title = 'x'}) => Todo(
    id: id,
    title: title,
    category: Category.daily,
    dueAt: null,
    doneAt: null,
    createdAt: DateTime.utc(2026, 5, 27, 9),
    updatedAt: DateTime.utc(2026, 5, 27, 9),
    calendarEventId: null,
  );

  test('upsert: local 저장 + outbox enqueue + 즉시 push 성공 시 outbox 비움', () async {
    await repo.upsert(make());
    await Future<void>.delayed(Duration.zero); // unawaited flush 흡수
    await Future<void>.delayed(Duration.zero);

    expect(await db.todosDao.getById('a'), isNotNull);
    expect(api.upsertCalls.single.t.id, 'a');
    expect(api.upsertCalls.single.userId, 'u1');
    expect(await db.outboxDao.count(), 0);
  });

  test('deleteById: local 삭제 + outbox enqueue + 원격 delete 호출', () async {
    await repo.upsert(make());
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    api.upsertCalls.clear();
    await repo.deleteById('a');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(await db.todosDao.getById('a'), isNull);
    expect(api.deleteCalls, [('a', 'u1')]);
    expect(await db.outboxDao.count(), 0);
  });

  test('원격 fail 시 outbox 에 남음, flushPending 재시도 성공 시 비움', () async {
    api.failAll = true;
    await repo.upsert(make(id: 'b', title: 'pending'));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    // 첫 시도 fail → outbox 에 남아 있음.
    expect(await db.outboxDao.count(), 1);
    expect(await db.todosDao.getById('b'), isNotNull); // local 은 유지

    // 재시도 성공.
    api.failAll = false;
    await repo.flushPending();
    expect(await db.outboxDao.count(), 0);
    expect(api.upsertCalls.last.t.id, 'b');
  });

  test('userId null (미인증) → flushPending no-op (outbox 그대로 보존)', () async {
    userId = null;
    await repo.upsert(make(id: 'c'));
    await Future<void>.delayed(Duration.zero);

    expect(await db.outboxDao.count(), 1);
    expect(api.upsertCalls, isEmpty);

    // 인증 복구 후 flush.
    userId = 'u1';
    await repo.flushPending();
    expect(await db.outboxDao.count(), 0);
    expect(api.upsertCalls.single.t.id, 'c');
  });

  test('실패 후 후속 mutation 도 큐에 누적 → 순서 보존', () async {
    api.failAll = true;
    await repo.upsert(make(id: 'd1', title: '1'));
    await Future<void>.delayed(Duration.zero);
    await repo.upsert(make(id: 'd2', title: '2'));
    await Future<void>.delayed(Duration.zero);

    expect(await db.outboxDao.count(), 2);

    api.failAll = false;
    await repo.flushPending();

    expect(api.upsertCalls.map((c) => c.t.id), ['d1', 'd2']);
    expect(await db.outboxDao.count(), 0);
  });

  group('flushPending mutex (동시 호출 race 방지)', () {
    test('동시 호출 시 같은 outbox row 가 두 번 push 되지 않음', () async {
      // upsert 를 hold 시켜 첫 flush 가 진행 중인 상황을 만든다.
      api.holdNext = Completer<void>();
      await repo.upsert(make(id: 'r1'));

      // 잠깐 micro-task 만 진행 → flushPending 이 entry 를 잡고 upsert 대기 상태.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(api.upsertCalls, hasLength(1));

      // 같은 entry 를 두 번 처리하지 않는지 검증 — 두 번째 flushPending 호출.
      final secondFlush = repo.flushPending();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(api.upsertCalls, hasLength(1), reason: 'mutex 가 막아야 함');

      // hold 해제 → 첫 flush 종료 + rerun 으로 두 번째도 처리 시도 (하지만 outbox 비었음).
      api.holdNext!.complete();
      api.holdNext = null;
      await secondFlush;

      expect(api.upsertCalls, hasLength(1), reason: '동일 row 가 두 번 push 되면 안 됨');
      expect(await db.outboxDao.count(), 0);
    });

    test('flush 진행 중 새 mutation 이 enqueue 되면 rerun 으로 처리', () async {
      api.holdNext = Completer<void>();
      await repo.upsert(make(id: 's1'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(api.upsertCalls.single.t.id, 's1');

      // 첫 flush 가 hold 된 동안 새 mutation enqueue (이게 unawaited flushPending
      // 호출을 또 트리거하지만 mutex 가 막아 rerun 플래그만 set).
      await repo.upsert(make(id: 's2'));
      await Future<void>.delayed(Duration.zero);
      expect(api.upsertCalls, hasLength(1)); // 아직 첫 s1 만

      api.holdNext!.complete();
      api.holdNext = null;
      // rerun 으로 s2 처리.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(api.upsertCalls.map((c) => c.t.id), ['s1', 's2']);
      expect(await db.outboxDao.count(), 0);
    });
  });
}

class _FakeApi implements RemoteTodosApi {
  @override
  Future<List<Todo>> fetchAll(String userId) async => List.of(remoteStore);

  @override
  Todo todoFromRow(Map<String, dynamic> row) => throw UnimplementedError(); // 본 테스트는 realtime payload 사용 X

  final List<({Todo t, String userId})> upsertCalls = [];
  final List<(String, String)> deleteCalls = [];
  final List<Todo> remoteStore = [];

  /// true 동안 모든 호출 fail. 호출자가 명시적으로 false 로 만들어 회복.
  bool failAll = false;

  /// 다음 upsert 호출을 이 Completer 완료까지 hold — race 시뮬레이션용.
  Completer<void>? holdNext;

  @override
  Future<void> upsert(Todo todo, String userId) async {
    if (failAll) throw StateError('simulated network error');
    upsertCalls.add((t: todo, userId: userId));
    final hold = holdNext;
    if (hold != null) {
      await hold.future;
    }
    remoteStore.removeWhere((r) => r.id == todo.id);
    remoteStore.add(todo);
  }

  @override
  Future<void> deleteById(String id, String userId) async {
    if (failAll) throw StateError('simulated network error');
    deleteCalls.add((id, userId));
    remoteStore.removeWhere((r) => r.id == id);
  }
}
