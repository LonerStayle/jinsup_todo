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
import 'package:solo_todo/src/features/outline/tree_providers.dart';

void main() {
  /// HomeScreen 을 [stream] (controlled-async) 으로 띄운다. 실제 Drift 의존성 없이
  /// UI 만 결정성 있게 검증.
  Future<StreamController<List<Todo>>> mountWith(
    WidgetTester tester, {
    required DateTime fixedNow,
    ThemeData? theme,
    Stream<int>? outboxCountStream,
    List<Todo> allTodos = const [],
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
          // v1.1 — breadcrumb 용 allTodosProvider. Drift 의존 + timer leak 회피.
          allTodosProvider.overrideWith((_) => Stream.value(allTodos)),
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
    // fast-tasks — 시간 모드는 "시작 M/D HH:mm" 라벨로 표시 (시각 포함).
    expect(find.textContaining('14:30'), findsOneWidget);
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

  group('v1.1 — today breadcrumb (트리 path 표시)', () {
    testWidgets('parentId null 인 root todo → 카테고리 라벨 breadcrumb', (
      tester,
    ) async {
      final t = todo(id: 'r', title: '회사 todo', category: Category.work);
      final controller = await mountWith(
        tester,
        fixedNow: DateTime(2026, 5, 27, 10),
        allTodos: [t],
      );
      controller.add([t]);
      await tester.pump();

      expect(
        find.text('회사 할일'),
        findsOneWidget,
        reason: 'root todo 는 카테고리 라벨만',
      );
    });

    testWidgets('parentId 가 있는 자식 → 부모 chain 의 title 만 breadcrumb', (
      tester,
    ) async {
      final parent = todo(id: 'p', title: 'JS슈퍼', category: Category.work);
      final child = Todo(
        id: 'c',
        title: '워크트리 만들기',
        category: Category.work,
        dueAt: null,
        doneAt: null,
        createdAt: DateTime.utc(2026, 5, 27, 1),
        updatedAt: DateTime.utc(2026, 5, 27, 1),
        calendarEventId: null,
        parentId: 'p',
      );
      final controller = await mountWith(
        tester,
        fixedNow: DateTime(2026, 5, 27, 10),
        allTodos: [parent, child],
      );
      controller.add([child]);
      await tester.pump();

      // breadcrumb 가 부모 title 만 (자식 자신 제외).
      expect(find.text('JS슈퍼'), findsOneWidget);
      expect(find.text('워크트리 만들기'), findsOneWidget);
      // 카테고리 라벨 (회사 할일) 은 화면 헤더에는 없어도 brc 자리에는 안 나옴.
    });

    testWidgets('손자 todo → "root / 직속부모" join 으로 breadcrumb', (tester) async {
      final root = todo(id: 'r', title: '개인 TODO', category: Category.idea);
      final mid = Todo(
        id: 'm',
        title: 'JS슈퍼',
        category: Category.idea,
        dueAt: null,
        doneAt: null,
        createdAt: DateTime.utc(2026, 5, 27, 1),
        updatedAt: DateTime.utc(2026, 5, 27, 1),
        calendarEventId: null,
        parentId: 'r',
      );
      final leaf = Todo(
        id: 'l',
        title: '서브에이전트 처리',
        category: Category.idea,
        dueAt: null,
        doneAt: null,
        createdAt: DateTime.utc(2026, 5, 27, 1),
        updatedAt: DateTime.utc(2026, 5, 27, 1),
        calendarEventId: null,
        parentId: 'm',
      );
      final controller = await mountWith(
        tester,
        fixedNow: DateTime(2026, 5, 27, 10),
        allTodos: [root, mid, leaf],
      );
      controller.add([leaf]);
      await tester.pump();

      expect(
        find.text('개인 TODO / JS슈퍼'),
        findsOneWidget,
        reason: 'root → 직속부모 순으로 " / " join',
      );
    });

    testWidgets('breadcrumb 위젯 — onSurfaceVariant 색 + labelSmall typography', (
      tester,
    ) async {
      final t = todo(id: 'a', title: 'x');
      final controller = await mountWith(
        tester,
        fixedNow: DateTime(2026, 5, 27, 10),
        allTodos: [t],
      );
      controller.add([t]);
      await tester.pump();

      // breadcrumb Text 위젯의 스타일 검증 — 색은 onSurfaceVariant 와 일치.
      final textWidget = tester.widget<Text>(find.text('일상'));
      final scheme = AppTheme.mobileLight().colorScheme;
      expect(textWidget.style?.color, scheme.onSurfaceVariant);
    });
  });
}
