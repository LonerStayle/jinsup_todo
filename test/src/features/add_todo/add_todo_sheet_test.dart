import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/core/theme.dart';
import 'package:solo_todo/src/domain/category.dart';
import 'package:solo_todo/src/features/add_todo/add_todo_sheet.dart';

void main() {
  Future<List<AddTodoSubmission>> mount(
    WidgetTester tester, {
    Category initial = Category.daily,
    DateTime? initialDueAt,
    bool initialAllDay = true,
  }) async {
    // 종일/시간 토글 + Calendar 토글까지 추가되면서 sheet 가 길어졌다.
    // 800px 기본 viewport 로는 _Actions row 가 밖으로 밀려나 tap 이 무시된다.
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final submissions = <AddTodoSubmission>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.mobileLight(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: AddTodoSheet(
              initialCategory: initial,
              initialDueAt: initialDueAt,
              initialAllDay: initialAllDay,
              onSubmit: submissions.add,
            ),
          ),
        ),
      ),
    );
    return submissions;
  }

  testWidgets('title 비어 있으면 "추가" 비활성, 입력 후 활성화', (tester) async {
    final submissions = await mount(tester);

    final addBtn = find.widgetWithText(FilledButton, '추가');
    expect(addBtn, findsOneWidget);
    expect(tester.widget<FilledButton>(addBtn).onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('add-todo-title')),
      '회의 정리',
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(addBtn).onPressed, isNotNull);
    expect(submissions, isEmpty);
  });

  testWidgets('"추가" 누르면 onSubmit 호출 + 입력값 그대로', (tester) async {
    final submissions = await mount(tester, initial: Category.work);

    await tester.enterText(
      find.byKey(const ValueKey('add-todo-title')),
      '  보고서  ',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '추가'));
    await tester.pump();

    expect(submissions, hasLength(1));
    expect(submissions.first.title, '보고서'); // trim
    expect(submissions.first.category, Category.work); // initial
    expect(submissions.first.dueAt, isNull);
    expect(submissions.first.addToCalendar, isFalse); // due 없으니 강제 false
  });

  testWidgets('카테고리 chip 탭하면 selection 변경', (tester) async {
    final submissions = await mount(tester);

    await tester.enterText(find.byKey(const ValueKey('add-todo-title')), 'x');
    await tester.tap(find.text('개인개발'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '추가'));
    await tester.pump();

    expect(submissions.first.category, Category.personalDev);
  });

  testWidgets('일정 비어 있을 때 Calendar 토글이 안 보임', (tester) async {
    await mount(tester);
    expect(find.text('Google Calendar 에 등록'), findsNothing);
  });

  testWidgets('Enter (onSubmitted) 로도 저장 가능', (tester) async {
    final submissions = await mount(tester);

    await tester.enterText(
      find.byKey(const ValueKey('add-todo-title')),
      '빠른 추가',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(submissions, hasLength(1));
    expect(submissions.first.title, '빠른 추가');
  });

  group('하루 종일 옵션 (시간 picker 강제 제거)', () {
    testWidgets('initialDueAt + initialAllDay=true → 라벨이 "· 하루 종일" 로 표시', (
      tester,
    ) async {
      await mount(
        tester,
        initialDueAt: DateTime(2026, 5, 28),
        initialAllDay: true,
      );

      expect(find.textContaining('하루 종일'), findsWidgets);
      // 종일 상태에서는 "시간 추가" 액션이 나오고 "하루 종일" 토글 버튼은 안 나옴.
      expect(find.widgetWithText(OutlinedButton, '시간 추가'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, '하루 종일'), findsNothing);
    });

    testWidgets('종일 상태로 추가 → submission.isAllDay == true + dueAt 시간 부분 00:00', (
      tester,
    ) async {
      final submissions = await mount(
        tester,
        initialDueAt: DateTime(2026, 5, 28),
        initialAllDay: true,
      );

      await tester.enterText(
        find.byKey(const ValueKey('add-todo-title')),
        '하루 일정',
      );
      await tester.pump();
      // viewport 의존성 회피 — onPressed 직접 호출.
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '추가'))
          .onPressed!();
      await tester.pump();

      expect(submissions, hasLength(1));
      expect(submissions.first.dueAt, DateTime(2026, 5, 28));
      expect(submissions.first.isAllDay, isTrue);
    });

    testWidgets('initialAllDay=false (시간 지정) → "시간 변경" + "하루 종일" 토글 모두 노출', (
      tester,
    ) async {
      await mount(
        tester,
        initialDueAt: DateTime(2026, 5, 28, 14, 30),
        initialAllDay: false,
      );

      expect(find.textContaining('14:30'), findsWidgets);
      expect(find.widgetWithText(OutlinedButton, '시간 변경'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, '하루 종일'), findsOneWidget);
    });

    testWidgets('"하루 종일" 토글 누르면 시간이 00:00 으로 리셋되고 라벨이 종일로 변경', (tester) async {
      final submissions = await mount(
        tester,
        initialDueAt: DateTime(2026, 5, 28, 14, 30),
        initialAllDay: false,
      );

      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '하루 종일'))
          .onPressed!();
      await tester.pump();

      expect(find.textContaining('하루 종일'), findsWidgets);

      await tester.enterText(find.byKey(const ValueKey('add-todo-title')), 'x');
      await tester.pump();
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '추가'))
          .onPressed!();
      await tester.pump();

      expect(submissions.first.dueAt, DateTime(2026, 5, 28));
      expect(submissions.first.isAllDay, isTrue);
    });

    testWidgets('일정 없음 (dueAt null) → 종일/시간 버튼 둘 다 안 보임', (tester) async {
      await mount(tester); // initialDueAt 미주입
      expect(find.widgetWithText(OutlinedButton, '시간 추가'), findsNothing);
      expect(find.widgetWithText(OutlinedButton, '시간 변경'), findsNothing);
      expect(find.widgetWithText(OutlinedButton, '하루 종일'), findsNothing);
    });
  });
}
