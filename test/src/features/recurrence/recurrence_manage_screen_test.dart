import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/data/local/app_database.dart';
import 'package:solo_todo/src/data/providers.dart';
import 'package:solo_todo/src/domain/category.dart';
import 'package:solo_todo/src/domain/recurrence.dart';
import 'package:solo_todo/src/domain/todo.dart';
import 'package:solo_todo/src/features/recurrence/recurrence_manage_screen.dart';

Todo _master() => Todo(
  id: 'm1',
  title: '매주 정산',
  category: Category.work,
  dueAt: DateTime(2026, 1, 5, 9),
  doneAt: null,
  createdAt: DateTime(2026, 1, 5),
  updatedAt: DateTime(2026, 1, 5),
  seriesId: 'm1',
  recurrenceRule: const RecurrenceRule(freq: RecurrenceFreq.weekly).encode(),
  isSeriesMaster: true,
);

void main() {
  group('describeRecurrence', () {
    test('매일', () {
      expect(
        describeRecurrence(
          const RecurrenceRule(freq: RecurrenceFreq.daily),
          null,
        ),
        '매일',
      );
    });

    test('격주 + 요일', () {
      final r = RecurrenceRule(
        freq: RecurrenceFreq.weekly,
        interval: 2,
        byWeekday: const {DateTime.monday, DateTime.wednesday},
      );
      expect(describeRecurrence(r, null), '2주마다 (월·수)');
    });

    test('매월 + 종료일', () {
      expect(
        describeRecurrence(
          const RecurrenceRule(freq: RecurrenceFreq.monthly),
          DateTime(2026, 12, 31),
        ),
        contains('매개월 · '),
      );
    });
  });

  testWidgets('마스터 없으면 빈 상태', (tester) async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: RecurrenceManageScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('반복 중인 할 일이 없어요'), findsOneWidget);
  });

  testWidgets('마스터 있으면 카드 + 규칙 요약 + 반복중지 버튼', (tester) async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    await db.todosDao.upsert(_master());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: RecurrenceManageScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('매주 정산'), findsOneWidget);
    expect(find.text('매주'), findsOneWidget);
    expect(find.byKey(const ValueKey('recur-stop-m1')), findsOneWidget);
  });
}
