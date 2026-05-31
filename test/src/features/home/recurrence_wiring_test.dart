import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/data/local/app_database.dart';
import 'package:solo_todo/src/data/providers.dart';
import 'package:solo_todo/src/domain/category.dart';
import 'package:solo_todo/src/domain/recurrence.dart';
import 'package:solo_todo/src/domain/todo.dart';
import 'package:solo_todo/src/features/home/today_providers.dart';

ProviderContainer _makeContainer(AppDatabase db) => ProviderContainer(
  overrides: [
    appDatabaseProvider.overrideWithValue(db),
    nowProvider.overrideWithValue(() => clock.now()),
  ],
);

Todo _master({
  required String id,
  required RecurrenceRule rule,
  required DateTime dueAt,
}) => Todo(
  id: id,
  title: '매일 비타민',
  category: Category.daily,
  dueAt: dueAt,
  doneAt: null,
  createdAt: dueAt,
  updatedAt: dueAt,
  seriesId: id,
  recurrenceRule: rule.encode(),
  isSeriesMaster: true,
);

void main() {
  group('recurrenceMaterializerProvider', () {
    test('누락 인스턴스를 결정적 id 로 생성', () {
      fakeAsync((async) {
        final db = AppDatabase.memory();
        final container = _makeContainer(db);
        addTearDown(() async {
          container.dispose();
          await db.close();
        });

        db.todosDao.upsert(
          _master(
            id: 'm1',
            rule: const RecurrenceRule(freq: RecurrenceFreq.daily),
            dueAt: DateTime(2026, 1, 1),
          ),
        );
        async.flushMicrotasks();

        container.read(recurrenceMaterializerProvider); // 활성화
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 1));
        async.flushMicrotasks();

        var all = <Todo>[];
        db.todosDao.watchAll().first.then((v) => all = v);
        async.flushMicrotasks();

        final inst = all
            .where((t) => t.seriesId == 'm1' && !t.isSeriesMaster)
            .toList();
        expect(inst.length, 5); // 1/1~1/5
        expect(inst.map((t) => t.id).toSet(), {
          'm1#20260101',
          'm1#20260102',
          'm1#20260103',
          'm1#20260104',
          'm1#20260105',
        }, reason: '결정적 id — 중복 불가');
      }, initialTime: DateTime(2026, 1, 5, 12));
    });

    test('재평가해도 중복 없음 (결정적 id 멱등)', () {
      fakeAsync((async) {
        final db = AppDatabase.memory();
        final container = _makeContainer(db);
        addTearDown(() async {
          container.dispose();
          await db.close();
        });

        db.todosDao.upsert(
          _master(
            id: 'm1',
            rule: const RecurrenceRule(freq: RecurrenceFreq.daily),
            dueAt: DateTime(2026, 1, 4),
          ),
        );
        async.flushMicrotasks();

        container.read(recurrenceMaterializerProvider);
        // 여러 차례 재평가 유도.
        for (var i = 0; i < 5; i++) {
          async.flushMicrotasks();
          async.elapse(const Duration(milliseconds: 1));
        }
        async.flushMicrotasks();

        var all = <Todo>[];
        db.todosDao.watchAll().first.then((v) => all = v);
        async.flushMicrotasks();

        final inst = all
            .where((t) => t.seriesId == 'm1' && !t.isSeriesMaster)
            .toList();
        expect(inst.length, 2); // 1/4, 1/5 — 반복 평가에도 2건 유지
      }, initialTime: DateTime(2026, 1, 5, 12));
    });
  });

  test('dedupedTodayProvider — 같은 시리즈 미체크 누적은 1건만 노출', () {
    fakeAsync((async) {
      final db = AppDatabase.memory();
      final container = _makeContainer(db);
      addTearDown(() async {
        container.dispose();
        await db.close();
      });

      db.todosDao.upsert(
        _master(
          id: 'm1',
          rule: const RecurrenceRule(freq: RecurrenceFreq.daily),
          dueAt: DateTime(2026, 1, 1),
        ),
      );
      for (final d in [3, 4, 5]) {
        db.todosDao.upsert(
          Todo(
            id: 'm1#2026010$d',
            title: '매일 비타민',
            category: Category.daily,
            dueAt: DateTime(2026, 1, d, 9),
            doneAt: null,
            createdAt: DateTime(2026, 1, d),
            updatedAt: DateTime(2026, 1, d),
            seriesId: 'm1',
          ),
        );
      }
      async.flushMicrotasks();

      container.listen(watchTodayTodosProvider, (_, _) {});
      async.flushMicrotasks();

      final deduped = container.read(dedupedTodayProvider);
      final seriesVisible = deduped.visible
          .where((t) => t.seriesId == 'm1')
          .toList();
      expect(seriesVisible.length, 1, reason: 'leader 1건만');
      expect(seriesVisible.single.dueAt!.day, 3, reason: '가장 이른 발생분이 leader');
      expect(deduped.hiddenCountBySeries['m1'], 2);
      expect(deduped.visible.any((t) => t.isSeriesMaster), isFalse);
    }, initialTime: DateTime(2026, 1, 5, 12));
  });
}
