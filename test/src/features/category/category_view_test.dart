import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/core/theme.dart';
import 'package:solo_todo/src/domain/category.dart';
import 'package:solo_todo/src/domain/todo.dart';
import 'package:solo_todo/src/features/category/category_providers.dart';
import 'package:solo_todo/src/features/category/category_view.dart';

void main() {
  Future<StreamController<List<Todo>>> mount(
    WidgetTester tester, {
    required Category category,
  }) async {
    final controller = StreamController<List<Todo>>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          watchTodosByCategoryProvider(
            category,
          ).overrideWith((_) => controller.stream),
        ],
        child: MaterialApp(
          theme: AppTheme.mobileLight(),
          home: Scaffold(body: CategoryView(category: category)),
        ),
      ),
    );
    return controller;
  }

  Todo todo({
    required String id,
    required Category category,
    String title = 'x',
    DateTime? doneAt,
    TodoType type = TodoType.task,
  }) => Todo(
    id: id,
    title: title,
    category: category,
    type: type,
    dueAt: null,
    doneAt: doneAt,
    createdAt: DateTime.utc(2026, 5, 27),
    updatedAt: DateTime.utc(2026, 5, 27),
    calendarEventId: null,
  );

  testWidgets('빈 list → "{label}에 할 일이 없어요"', (tester) async {
    final controller = await mount(tester, category: Category.work);
    controller.add(<Todo>[]);
    await tester.pump();

    expect(find.text('회사 할일에 할 일이 없어요'), findsOneWidget);
  });

  testWidgets('미체크 2 + 완료 1 → 통계 chip 과 3개 tile', (tester) async {
    final controller = await mount(tester, category: Category.idea);
    controller.add([
      todo(id: '1', category: Category.idea, title: '아이디어 A'),
      todo(id: '2', category: Category.idea, title: '아이디어 B'),
      todo(
        id: '3',
        category: Category.idea,
        title: '아이디어 C 완료',
        doneAt: DateTime.utc(2026, 5, 27, 12),
      ),
    ]);
    await tester.pump();

    expect(find.text('아이디어 A'), findsOneWidget);
    expect(find.text('아이디어 B'), findsOneWidget);
    expect(find.text('아이디어 C 완료'), findsOneWidget);
    expect(find.text('미체크 2'), findsOneWidget);
    expect(find.text('완료 1'), findsOneWidget);
  });

  testWidgets('메모(note)는 미체크/완료 카운트에서 제외된다', (tester) async {
    final controller = await mount(tester, category: Category.idea);
    controller.add([
      todo(id: '1', category: Category.idea, title: '태스크 미체크'),
      todo(
        id: '2',
        category: Category.idea,
        title: '태스크 완료',
        doneAt: DateTime.utc(2026, 5, 27, 12),
      ),
      // note 는 체크 개념이 없어 카운트에서 빠져야 한다 (예전엔 미체크로 잘못 셈).
      // 제목을 '참고 노트'로 — §13 "메모" 라벨 칩 텍스트와 충돌 회피.
      todo(
        id: '3',
        category: Category.idea,
        title: '참고 노트',
        type: TodoType.note,
      ),
    ]);
    await tester.pump();

    expect(find.text('참고 노트'), findsOneWidget);
    expect(find.text('미체크 1'), findsOneWidget);
    expect(find.text('완료 1'), findsOneWidget);
  });

  testWidgets('헤더에 카테고리 한글 라벨 노출', (tester) async {
    final controller = await mount(tester, category: Category.personalDev);
    controller.add(<Todo>[]);
    await tester.pump();

    expect(find.text('개인개발'), findsAtLeastNWidgets(1));
  });
}
