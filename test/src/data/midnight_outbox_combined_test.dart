import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/data/day_boundary_provider.dart';
import 'package:solo_todo/src/data/local/app_database.dart';
import 'package:solo_todo/src/data/providers.dart';
import 'package:solo_todo/src/data/remote/supabase_todos_api.dart';
import 'package:solo_todo/src/data/syncing_todo_repository.dart';
import 'package:solo_todo/src/domain/category.dart';
import 'package:solo_todo/src/domain/todo.dart';

/// 자정 trigger + outbox flush 가 결합한 시나리오.
///
/// 어제 미체크 todo 가 자정 통과 후 carryover 로 분류되고, 그 todo 를 체크하면
/// outbox push 까지 정상 동작하는지. 자정 Timer 와 mutation 의 race 가 데이터 손실로
/// 이어지지 않음을 검증.
void main() {
  test('자정 통과 후 어제 todo 체크 → outbox 정상 flush', () {
    fakeAsync((async) {
      final db = AppDatabase.memory();
      final api = _FakeApi();
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          nowProvider.overrideWithValue(() => clock.now()),
          // 진짜 SyncingTodoRepository (outbox 포함) — 단, api 는 fake.
          todoRepositoryProvider.overrideWith((ref) {
            return SyncingTodoRepository(
              local: db.todosDao,
              outbox: db.outboxDao,
              api: api,
              userIdGetter: () => 'u1',
            );
          }),
        ],
      );

      // 어제 dueAt 미체크 todo seed.
      final yesterday = clock.now().subtract(const Duration(hours: 12));
      final todo = Todo(
        id: 't1',
        title: '어제 못 끝낸 일',
        category: Category.work,
        dueAt: yesterday,
        doneAt: null,
        createdAt: yesterday,
        updatedAt: yesterday,
        calendarEventId: null,
      );

      // pre-seed local DB (이미 어제 sync 됐던 row 가정).
      db.todosDao.upsert(todo);
      async.flushMicrotasks();

      // currentDayProvider 초기화 → 어제 자정 emit (now=23:59:30 의 today).
      final initialDay = container.read(currentDayProvider);
      expect(initialDay, DateTime(2026, 5, 27, 0, 0));

      // 자정 통과 — Timer fire.
      async.elapse(const Duration(minutes: 1, seconds: 5));
      final newDay = container.read(currentDayProvider);
      expect(
        newDay,
        DateTime(2026, 5, 28, 0, 0),
        reason: '자정 통과 후 currentDayProvider 가 다음날 자정으로 emit',
      );

      // 자정 통과 후 사용자가 어제 todo 를 체크 → mutation + outbox.
      final repo = container.read(todoRepositoryProvider);
      final toggled = todo.copyWith(
        doneAt: clock.now(),
        updatedAt: clock.now(),
      );
      repo.upsert(toggled);
      // microtask 만 drain — flushTimers 는 currentDayProvider 가 매 자정 self-reschedule
      // 하므로 무한 loop. 작은 elapse 로 outbox flush 의 unawaited future 진행.
      async.flushMicrotasks();
      async.elapse(const Duration(milliseconds: 10));
      async.flushMicrotasks();

      // outbox flush 가 unawaited 로 호출 → fake api 까지 push 도달.
      expect(api.upsertCalls.last.t.id, 't1');
      expect(api.upsertCalls.last.t.isDone, isTrue);

      // 정리 — Timer leak 방지.
      container.dispose();
      db.close();
    }, initialTime: DateTime(2026, 5, 27, 23, 59, 30));
  });
}

class _FakeApi implements RemoteTodosApi {
  final List<({Todo t, String userId})> upsertCalls = [];

  @override
  Future<List<Todo>> fetchAll(String userId) async => const [];

  @override
  Todo todoFromRow(Map<String, dynamic> row) => throw UnimplementedError();

  @override
  Future<void> upsert(Todo todo, String userId) async {
    upsertCalls.add((t: todo, userId: userId));
  }

  @override
  Future<void> deleteById(String id, String userId) async {}
}
