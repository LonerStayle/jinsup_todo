import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/core/theme.dart';
import 'package:solo_todo/src/data/providers.dart';
import 'package:solo_todo/src/domain/category.dart';
import 'package:solo_todo/src/domain/todo.dart';
import 'package:solo_todo/src/features/home/home_screen.dart';
import 'package:solo_todo/src/features/home/today_providers.dart';

void main() {
  /// HomeScreen 을 [stream] (controlled-async) 으로 띄운다. 실제 Drift 의존성 없이
  /// UI 만 결정성 있게 검증.
  Future<StreamController<List<Todo>>> mountWith(
    WidgetTester tester, {
    required DateTime fixedNow,
  }) async {
    final controller = StreamController<List<Todo>>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nowProvider.overrideWithValue(() => fixedNow),
          watchTodayTodosProvider.overrideWith((_) => controller.stream),
        ],
        child: MaterialApp(
          theme: AppTheme.mobileLight(),
          home: const Scaffold(body: HomeScreen()),
        ),
      ),
    );
    return controller;
  }

  Todo todo({
    required String id,
    String title = 'x',
    Category category = Category.daily,
    DateTime? dueAt,
    DateTime? doneAt,
    DateTime? createdAt,
  }) {
    final c = createdAt ?? DateTime.utc(2026, 5, 27, 1);
    return Todo(
      id: id,
      title: title,
      category: category,
      dueAt: dueAt,
      doneAt: doneAt,
      createdAt: c,
      updatedAt: c,
      calendarEventId: null,
    );
  }

  testWidgets('빈 list → 빈 상태 ("오늘 할 일이 없어요") + 이월 배너 없음', (tester) async {
    final controller = await mountWith(
      tester,
      fixedNow: DateTime(2026, 5, 27, 10),
    );
    controller.add(<Todo>[]);
    await tester.pump();

    expect(find.text('오늘 할 일이 없어요'), findsOneWidget);
    expect(find.textContaining('이월'), findsNothing);
  });

  testWidgets('오늘 todo 1건 — title + 시간 노출, 이월 배너 없음', (tester) async {
    final controller = await mountWith(
      tester,
      fixedNow: DateTime(2026, 5, 27, 10),
    );
    controller.add([
      todo(
        id: 'a',
        title: 'PR 리뷰',
        category: Category.personalDev,
        dueAt: DateTime(2026, 5, 27, 14, 30),
      ),
    ]);
    await tester.pump();

    expect(find.text('PR 리뷰'), findsOneWidget);
    expect(find.text('14:30'), findsOneWidget);
    expect(find.textContaining('이월'), findsNothing);
  });

  testWidgets('어제 미체크 todo 가 있을 때 이월 배너 노출', (tester) async {
    final controller = await mountWith(
      tester,
      fixedNow: DateTime(2026, 5, 27, 10),
    );
    controller.add([
      todo(
        id: 'y',
        title: '어제 못 끝낸 일',
        category: Category.work,
        dueAt: DateTime(2026, 5, 26, 9),
        createdAt: DateTime.utc(2026, 5, 26),
      ),
    ]);
    await tester.pump();

    expect(find.text('어제 못 끝낸 일'), findsOneWidget);
    expect(find.textContaining('1건이 오늘로 이월'), findsOneWidget);
  });
}
