import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solo_todo/src/data/local/app_database.dart';
import 'package:solo_todo/src/data/providers.dart';
import 'package:solo_todo/src/domain/category.dart';
import 'package:solo_todo/src/domain/recurrence.dart';
import 'package:solo_todo/src/features/add_todo/add_todo_sheet.dart';

void main() {
  final submissions = <AddTodoSubmission>[];

  setUp(submissions.clear);

  Widget host({DateTime? initialDueAt}) => ProviderScope(
    overrides: [appDatabaseProvider.overrideWithValue(AppDatabase.memory())],
    child: MaterialApp(
      home: Scaffold(
        body: AddTodoSheet(
          onSubmit: submissions.add,
          initialCategory: Category.work,
          initialDueAt: initialDueAt,
          now: () => DateTime(2026, 1, 5, 9), // 월요일
        ),
      ),
    ),
  );

  testWidgets('날짜 없으면 반복 섹션 숨김', (tester) async {
    await tester.pumpWidget(host());
    expect(find.text('반복'), findsNothing);
    expect(find.byKey(const ValueKey('recur-freq-none')), findsNothing);
  });

  testWidgets('날짜 있으면 반복 섹션 노출, 기본 "안 함"', (tester) async {
    await tester.pumpWidget(host(initialDueAt: DateTime(2026, 1, 5)));
    expect(find.text('반복'), findsOneWidget);
    expect(find.byKey(const ValueKey('recur-freq-none')), findsOneWidget);
    // 안 함 상태 — interval/요일 미노출.
    expect(find.byKey(const ValueKey('recur-interval-label')), findsNothing);
  });

  testWidgets('매일 선택 + 제목 입력 → submission.recurrence = daily', (tester) async {
    await tester.pumpWidget(host(initialDueAt: DateTime(2026, 1, 5)));
    await tester.enterText(find.byType(TextField).first, '비타민');
    await tester.tap(find.byKey(const ValueKey('recur-freq-daily')));
    await tester.pump();
    expect(find.byKey(const ValueKey('recur-interval-label')), findsOneWidget);
    await tester.tap(find.text('추가'));
    await tester.pump();

    expect(submissions, hasLength(1));
    expect(
      submissions.single.recurrence,
      const RecurrenceRule(freq: RecurrenceFreq.daily),
    );
  });

  testWidgets('간격 스텝퍼 +1 → interval 2', (tester) async {
    await tester.pumpWidget(host(initialDueAt: DateTime(2026, 1, 5)));
    await tester.enterText(find.byType(TextField).first, '격주 회의');
    await tester.tap(find.byKey(const ValueKey('recur-freq-weekly')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('recur-interval-plus')));
    await tester.pump();
    expect(find.text('2주마다'), findsOneWidget);
    await tester.tap(find.text('추가'));
    await tester.pump();

    final r = submissions.single.recurrence!;
    expect(r.freq, RecurrenceFreq.weekly);
    expect(r.interval, 2);
    // 매주 선택 시 dueAt(월요일=1) 요일이 기본으로 켜진다.
    expect(r.byWeekday, contains(DateTime.monday));
  });

  testWidgets('매주 요일 토글 — 수요일 추가', (tester) async {
    await tester.pumpWidget(host(initialDueAt: DateTime(2026, 1, 5)));
    await tester.enterText(find.byType(TextField).first, '주간보고');
    await tester.tap(find.byKey(const ValueKey('recur-freq-weekly')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('recur-weekday-3'))); // 수
    await tester.pump();
    await tester.tap(find.text('추가'));
    await tester.pump();

    final r = submissions.single.recurrence!;
    expect(r.byWeekday, containsAll([DateTime.monday, DateTime.wednesday]));
  });

  testWidgets('안 함이면 submission.recurrence = null', (tester) async {
    await tester.pumpWidget(host(initialDueAt: DateTime(2026, 1, 5)));
    await tester.enterText(find.byType(TextField).first, '단발 할일');
    await tester.tap(find.text('추가'));
    await tester.pump();
    expect(submissions.single.recurrence, isNull);
  });
}
