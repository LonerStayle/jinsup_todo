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
    ThemeData? theme,
    Stream<int>? outboxCountStream,
  }) async {
    final controller = StreamController<List<Todo>>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nowProvider.overrideWithValue(() => fixedNow),
          watchTodayTodosProvider.overrideWith((_) => controller.stream),
          outboxCountProvider.overrideWith(
            (_) => outboxCountStream ?? Stream<int>.value(0),
          ),
        ],
        child: MaterialApp(
          theme: theme ?? AppTheme.mobileLight(),
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

  testWidgets('이월 배너 — light 테마에서 bg alpha 0.08', (tester) async {
    final controller = await mountWith(
      tester,
      fixedNow: DateTime(2026, 5, 27, 10),
      theme: AppTheme.mobileLight(),
    );
    controller.add([
      todo(
        id: 'y',
        category: Category.work,
        dueAt: DateTime(2026, 5, 26, 9),
        createdAt: DateTime.utc(2026, 5, 26),
      ),
    ]);
    await tester.pump();

    final banner = tester.widget<Container>(
      find.byKey(const ValueKey('carryover-banner')),
    );
    final bgAlpha = (banner.decoration! as BoxDecoration).color!.a;
    expect(bgAlpha, closeTo(0.08, 0.005));
  });

  testWidgets('outbox count == 0 → 동기화 chip 안 보임', (tester) async {
    final controller = await mountWith(
      tester,
      fixedNow: DateTime(2026, 5, 27, 10),
    );
    controller.add(<Todo>[]);
    await tester.pump();

    expect(find.byKey(const ValueKey('sync-pending-chip')), findsNothing);
  });

  testWidgets('outbox count > 0 → "동기화 대기 N건" chip 노출', (tester) async {
    // broadcast stream — 첫 emit 이 listener 등록 후 들어오도록.
    final outboxStream = Stream<int>.value(3).asBroadcastStream();
    final controller = await mountWith(
      tester,
      fixedNow: DateTime(2026, 5, 27, 10),
      outboxCountStream: outboxStream,
    );
    controller.add(<Todo>[]);
    // stream emit + AsyncValue.data 반영을 위해 pump 두 번.
    await tester.pump();
    await tester.pump(Duration.zero);

    expect(find.byKey(const ValueKey('sync-pending-chip')), findsOneWidget);
    expect(find.textContaining('동기화 대기 3건'), findsOneWidget);
  });

  testWidgets('이월 배너 — dark 테마에서 bg alpha 가 light 보다 진함 (다크 가독성)', (
    tester,
  ) async {
    final controller = await mountWith(
      tester,
      fixedNow: DateTime(2026, 5, 27, 10),
      theme: AppTheme.mobileDark(),
    );
    controller.add([
      todo(
        id: 'y',
        category: Category.work,
        dueAt: DateTime(2026, 5, 26, 9),
        createdAt: DateTime.utc(2026, 5, 26),
      ),
    ]);
    await tester.pump();

    final banner = tester.widget<Container>(
      find.byKey(const ValueKey('carryover-banner')),
    );
    final bgAlpha = (banner.decoration! as BoxDecoration).color!.a;
    expect(
      bgAlpha,
      greaterThan(0.10),
      reason: '다크에서 light 의 0.08 보다 충분히 진해야 가독성 보장',
    );
  });
}
