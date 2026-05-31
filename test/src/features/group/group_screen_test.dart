import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/core/theme.dart';
import 'package:solo_todo/src/data/providers.dart';
import 'package:solo_todo/src/domain/category.dart';
import 'package:solo_todo/src/domain/group.dart';
import 'package:solo_todo/src/domain/todo.dart';
import 'package:solo_todo/src/features/category/categories_controller.dart';
import 'package:solo_todo/src/features/category/groups_controller.dart';
import 'package:solo_todo/src/features/group/group_screen.dart';
import 'package:solo_todo/src/features/home/today_providers.dart';
import 'package:solo_todo/src/features/outline/tree_providers.dart';

/// A안 — 그룹 화면(오늘/전체보기 탭)이 그 그룹 카테고리로만 필터되는지 검증.
void main() {
  // 회사 그룹(g-a)에 묶인 '회사 할일' 카테고리 + 미분류 '개인개발' 카테고리.
  final companyGroup = const Group(
    id: 'g-a',
    label: '회사',
    colorValue: 0xFF2A66FF,
  );
  final workCat = Category.work.copyWith(groupId: 'g-a');
  final devCat = Category.personalDev; // groupId == null (미분류)

  Todo make({
    required String id,
    required String title,
    required Category category,
    String? parentId,
  }) => Todo(
    id: id,
    title: title,
    description: null,
    category: category,
    dueAt: null,
    doneAt: null,
    createdAt: DateTime.utc(2026, 5, 27, 9),
    updatedAt: DateTime.utc(2026, 5, 27, 9),
    calendarEventId: null,
    parentId: parentId,
    type: TodoType.task,
  );

  Future<void> mount(
    WidgetTester tester, {
    required List<Todo> todayTodos,
    required Map<Category, List<Todo>> rootsByCategory,
    required List<Todo> allTodos,
  }) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nowProvider.overrideWithValue(() => DateTime(2026, 5, 27, 12)),
          watchTodayTodosProvider.overrideWith((_) => Stream.value(todayTodos)),
          recurrenceMaterializerProvider.overrideWith((_) {}),
          allTodosProvider.overrideWith((_) => Stream.value(allTodos)),
          rootsOfCategoryProvider.overrideWith(
            (_, cat) => Stream.value(rootsByCategory[cat] ?? const <Todo>[]),
          ),
          childrenOfProvider.overrideWith((_, _) => Stream.value(const [])),
          categoriesProvider.overrideWith(
            (_) => Stream.value([workCat, devCat]),
          ),
          groupsProvider.overrideWith((_) => Stream.value([companyGroup])),
        ],
        child: MaterialApp(
          theme: AppTheme.mobileLight(),
          home: Scaffold(body: GroupScreen(group: companyGroup)),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
  }

  testWidgets('오늘 탭 — 그 그룹 카테고리의 할 일만 보인다', (tester) async {
    final inGroup = make(id: 't1', title: '회사 오늘', category: workCat);
    final outGroup = make(id: 't2', title: '개인 오늘', category: devCat);
    await mount(
      tester,
      todayTodos: [inGroup, outGroup],
      rootsByCategory: const {},
      allTodos: [inGroup, outGroup],
    );

    // 그룹 헤더 + 두 탭.
    expect(find.text('회사'), findsWidgets);
    expect(find.widgetWithText(Tab, '오늘'), findsOneWidget);
    expect(find.widgetWithText(Tab, '전체보기'), findsOneWidget);

    // 오늘 탭(default) — 회사 그룹 카테고리(work)만, 미분류 개인개발은 제외.
    expect(find.text('회사 오늘'), findsOneWidget);
    expect(find.text('개인 오늘'), findsNothing);
  });

  testWidgets('전체보기 탭 — 그 그룹 카테고리만 평면으로 (다른 카테고리 제외)', (tester) async {
    final workRoot = make(id: 'r1', title: '캔버스 작업', category: workCat);
    final devRoot = make(id: 'r2', title: '리팩터링', category: devCat);
    await mount(
      tester,
      todayTodos: const [],
      rootsByCategory: {
        workCat: [workRoot],
        devCat: [devRoot],
      },
      allTodos: [workRoot, devRoot],
    );

    await tester.tap(find.widgetWithText(Tab, '전체보기'));
    await tester.pumpAndSettle();

    // 회사 그룹 카테고리(work)와 그 task root 만 — 미분류 개인개발은 안 보인다.
    expect(find.text('회사 할일'), findsOneWidget);
    expect(find.text('캔버스 작업'), findsOneWidget);
    expect(find.text('개인개발'), findsNothing);
    expect(find.text('리팩터링'), findsNothing);
  });
}
