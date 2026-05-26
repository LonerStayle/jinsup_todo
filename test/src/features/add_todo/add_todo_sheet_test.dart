import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/core/theme.dart';
import 'package:solo_todo/src/domain/category.dart';
import 'package:solo_todo/src/features/add_todo/add_todo_sheet.dart';

void main() {
  Future<List<AddTodoSubmission>> mount(
    WidgetTester tester, {
    Category initial = Category.daily,
  }) async {
    final submissions = <AddTodoSubmission>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.mobileLight(),
        home: Scaffold(
          body: AddTodoSheet(
            initialCategory: initial,
            onSubmit: submissions.add,
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
}
