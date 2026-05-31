import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solo_todo/src/data/local/app_database.dart';
import 'package:solo_todo/src/data/providers.dart';
import 'package:solo_todo/src/domain/category.dart';
import 'package:solo_todo/src/domain/recurrence.dart';
import 'package:solo_todo/src/features/home/today_providers.dart';
import 'package:solo_todo/src/domain/todo.dart';

ProviderContainer _container(AppDatabase db, {DateTime Function()? now}) {
  final c = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      if (now != null) nowProvider.overrideWithValue(now),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

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
  test('recurrenceMaterializerProvider 가 누락 인스턴스를 DB 에 생성', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    await db.todosDao.upsert(
      _master(
        id: 'm1',
        rule: const RecurrenceRule(freq: RecurrenceFreq.daily),
        dueAt: DateTime(2026, 1, 1),
      ),
    );

    final c = _container(db, now: () => DateTime(2026, 1, 5, 12));
    c.read(recurrenceMaterializerProvider); // 활성화 → watchAll 구독 시작

    // 비동기 upsert 완료까지 폴링.
    var instances = <Todo>[];
    for (var i = 0; i < 80; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final all = await db.todosDao.watchAll().first;
      instances = all
          .where((t) => t.seriesId == 'm1' && !t.isSeriesMaster)
          .toList();
      if (instances.length >= 5) break;
    }
    // 1/1~1/5 daily = 5건.
    expect(instances.length, 5);
    expect(instances.map((t) => t.dueAt!.day).toList()..sort(), [
      1,
      2,
      3,
      4,
      5,
    ]);
    // 인스턴스는 규칙 미보유.
    expect(instances.every((t) => t.recurrenceRule == null), isTrue);
  });

  test('재실행해도 중복 생성 안 함 (idempotent)', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    await db.todosDao.upsert(
      _master(
        id: 'm1',
        rule: const RecurrenceRule(freq: RecurrenceFreq.daily),
        dueAt: DateTime(2026, 1, 4),
      ),
    );

    final c = _container(db, now: () => DateTime(2026, 1, 5, 12));
    c.read(recurrenceMaterializerProvider);
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final all = await db.todosDao.watchAll().first;
    final instances = all
        .where((t) => t.seriesId == 'm1' && !t.isSeriesMaster)
        .toList();
    expect(instances.length, 2); // 1/4, 1/5 만, 반복 호출에도 2건 유지
  });

  test('dedupedTodayProvider — 같은 시리즈 미체크 누적은 1건만 노출', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    // 마스터 + 미체크 인스턴스 3건(어제~그제~오늘) 직접 시드.
    await db.todosDao.upsert(
      _master(
        id: 'm1',
        rule: const RecurrenceRule(freq: RecurrenceFreq.daily),
        dueAt: DateTime(2026, 1, 1),
      ),
    );
    for (final d in [3, 4, 5]) {
      await db.todosDao.upsert(
        Todo(
          id: 'i$d',
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

    final c = _container(db, now: () => DateTime(2026, 1, 5, 12));
    // 오늘 스트림을 활성 구독 유지 + 3건 안정화까지 폴링 (첫 emit 레이스 회피).
    final sub = c.listen(watchTodayTodosProvider, (_, _) {});
    addTearDown(sub.close);
    DedupedToday deduped = const DedupedToday(
      visible: [],
      hiddenCountBySeries: {},
    );
    for (var i = 0; i < 80; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final raw = c.read(watchTodayTodosProvider).value ?? const [];
      final n = raw
          .where((t) => t.seriesId == 'm1' && !t.isSeriesMaster)
          .length;
      if (n == 3) {
        deduped = c.read(dedupedTodayProvider);
        break;
      }
    }

    final seriesVisible = deduped.visible
        .where((t) => t.seriesId == 'm1')
        .toList();
    expect(seriesVisible.length, 1, reason: 'leader 1건만');
    expect(seriesVisible.single.dueAt!.day, 3, reason: '가장 이른 발생분이 leader');
    expect(deduped.hiddenCountBySeries['m1'], 2);
    // 마스터는 오늘 목록에서 제외(VisibilityPolicy).
    expect(deduped.visible.any((t) => t.isSeriesMaster), isFalse);
  });
}
