import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/data/day_boundary_provider.dart';
import 'package:solo_todo/src/data/local/app_database.dart';
import 'package:solo_todo/src/data/providers.dart';
import 'package:solo_todo/src/domain/category.dart';
import 'package:solo_todo/src/domain/todo.dart';
import 'package:solo_todo/src/features/home/today_providers.dart';

/// 정리 트리거 integration:
///   VisibilityPolicy.isVisibleToday + currentDayProvider 자정 Timer + watchTodayTodosProvider
///   가 결합되어, 자정이 지나면 "어제 체크된 todo" 가 자동으로 사라진다.
void main() {
  test('자정 이후 어제 체크된 항목이 오늘 화면 stream 에서 자동으로 사라진다', () {
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

      // seed: 오늘 (5/27) 에 체크된 todo + 미체크 todo.
      db.todosDao.upsert(
        _buildTodo(
          id: 'done-today',
          title: '오늘 체크됨',
          doneAt: DateTime(2026, 5, 27, 15),
          createdAt: DateTime.utc(2026, 5, 27, 1),
        ),
      );
      db.todosDao.upsert(
        _buildTodo(
          id: 'undone',
          title: '미체크 (계속 보임)',
          createdAt: DateTime.utc(2026, 5, 27, 2),
        ),
      );

      // 첫 stream 구독 + drain. microtask 가 정리되어야 stream 의 첫 emit 도달.
      // ProviderContainer.read(streamProvider) 는 AsyncValue 를 즉시 반환하므로
      // future 를 직접 await 하지 않고 microtask 만 흘려서 첫 emit 확보.
      container.listen(watchTodayTodosProvider, (_, _) {});
      async.flushMicrotasks();

      final before = container.read(watchTodayTodosProvider).requireValue;
      expect(before.map((t) => t.id).toSet(), {'done-today', 'undone'});

      // 자정 + 안전 마진 elapse.
      final until = nextMidnightFrom(clock.now()) + const Duration(seconds: 2);
      async.elapse(until);
      async.flushMicrotasks();

      final after = container.read(watchTodayTodosProvider).requireValue;
      expect(
        after.map((t) => t.id).toSet(),
        {'undone'},
        reason: '어제 체크된 todo 는 자동 정리되고 미체크는 이월되어 그대로 보여야 함',
      );
    }, initialTime: DateTime(2026, 5, 27, 23, 59, 30));
  });
}

Todo _buildTodo({
  required String id,
  required String title,
  DateTime? doneAt,
  DateTime? createdAt,
}) {
  final c = createdAt ?? DateTime.utc(2026, 5, 27, 1);
  return Todo(
    id: id,
    title: title,
    category: Category.daily,
    dueAt: null,
    doneAt: doneAt,
    createdAt: c,
    updatedAt: c,
    calendarEventId: null,
  );
}
