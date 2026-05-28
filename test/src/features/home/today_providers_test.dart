import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/data/local/app_database.dart';
import 'package:solo_todo/src/data/providers.dart';
import 'package:solo_todo/src/domain/category.dart';
import 'package:solo_todo/src/domain/todo.dart';
import 'package:solo_todo/src/features/home/today_providers.dart';

/// today_providers (watchTodayTodos + carryoverCount) 가 dueAt null (시간 미지정,
/// "하루 종일") todo 를 비전 그대로 처리하는지 검증.
///
/// 핵심:
///   - dueAt 가 null 이면 effective date 는 createdAt 으로 본다 (CarryoverPolicy
///     + VisibilityPolicy 의 공통 규칙).
///   - 즉, dueAt null + createdAt 어제 + 미체크 = 오늘로 자동 이월 (visible + carry count).
///   - dueAt null + createdAt 오늘 + 미체크 = 오늘 신규 (visible, carry count X).
void main() {
  group('today_providers — dueAt null (하루 종일) todo', () {
    test('dueAt null + createdAt 어제 + 미체크 → 오늘 visible + carryover 1', () {
      fakeAsync((async) {
        final db = AppDatabase.memory();
        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            nowProvider.overrideWithValue(() => clock.now()),
          ],
        );
        addTearDown(() async {
          container.dispose();
          await db.close();
        });

        db.todosDao.upsert(
          _todo(id: 'carry', createdAt: DateTime.utc(2026, 5, 26, 9)),
        );

        container.listen(watchTodayTodosProvider, (_, _) {});
        async.flushMicrotasks();

        final visible = container.read(watchTodayTodosProvider).requireValue;
        expect(visible.map((t) => t.id), ['carry']);
        expect(
          container.read(carryoverCountProvider),
          1,
          reason: 'dueAt null + createdAt 어제 = effective 어제 → 이월 카운트에 포함',
        );
      }, initialTime: DateTime(2026, 5, 27, 10));
    });

    test('dueAt null + createdAt 오늘 + 미체크 → visible + carryover 0', () {
      fakeAsync((async) {
        final db = AppDatabase.memory();
        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            nowProvider.overrideWithValue(() => clock.now()),
          ],
        );
        addTearDown(() async {
          container.dispose();
          await db.close();
        });

        db.todosDao.upsert(
          _todo(id: 'fresh', createdAt: DateTime.utc(2026, 5, 27, 1)),
        );

        container.listen(watchTodayTodosProvider, (_, _) {});
        async.flushMicrotasks();

        expect(
          container.read(watchTodayTodosProvider).requireValue.map((t) => t.id),
          ['fresh'],
        );
        expect(
          container.read(carryoverCountProvider),
          0,
          reason: '오늘 생성된 dueAt null todo 는 이월이 아님',
        );
      }, initialTime: DateTime(2026, 5, 27, 10));
    });

    test('dueAt null + 어제 만들고 어제 체크됨 → hide (carry 카운트 X)', () {
      fakeAsync((async) {
        final db = AppDatabase.memory();
        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            nowProvider.overrideWithValue(() => clock.now()),
          ],
        );
        addTearDown(() async {
          container.dispose();
          await db.close();
        });

        db.todosDao.upsert(
          _todo(
            id: 'staleDone',
            createdAt: DateTime.utc(2026, 5, 26, 9),
            doneAt: DateTime(2026, 5, 26, 20),
          ),
        );

        container.listen(watchTodayTodosProvider, (_, _) {});
        async.flushMicrotasks();

        expect(
          container.read(watchTodayTodosProvider).requireValue,
          isEmpty,
          reason: '어제 체크된 항목은 자정 지나면 hide',
        );
        expect(container.read(carryoverCountProvider), 0);
      }, initialTime: DateTime(2026, 5, 27, 10));
    });

    test('dueAt null 어제 미체크 여러 건 → carryoverCount 가 개수만큼 누적', () {
      fakeAsync((async) {
        final db = AppDatabase.memory();
        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            nowProvider.overrideWithValue(() => clock.now()),
          ],
        );
        addTearDown(() async {
          container.dispose();
          await db.close();
        });

        db.todosDao.upsert(
          _todo(id: 'a', createdAt: DateTime.utc(2026, 5, 26, 9)),
        );
        db.todosDao.upsert(
          _todo(id: 'b', createdAt: DateTime.utc(2026, 5, 25, 9)),
        );
        db.todosDao.upsert(
          // dueAt null + 오늘 createdAt — 이월 카운트에 포함되면 안 됨
          _todo(id: 'today', createdAt: DateTime.utc(2026, 5, 27, 2)),
        );

        container.listen(watchTodayTodosProvider, (_, _) {});
        async.flushMicrotasks();

        expect(
          container
              .read(watchTodayTodosProvider)
              .requireValue
              .map((t) => t.id)
              .toSet(),
          {'a', 'b', 'today'},
        );
        expect(container.read(carryoverCountProvider), 2);
      }, initialTime: DateTime(2026, 5, 27, 10));
    });
  });
}

Todo _todo({
  required String id,
  required DateTime createdAt,
  DateTime? doneAt,
}) => Todo(
  id: id,
  title: '하루 종일 $id',
  category: Category.daily,
  dueAt: null,
  doneAt: doneAt,
  createdAt: createdAt,
  updatedAt: createdAt,
  calendarEventId: null,
);
