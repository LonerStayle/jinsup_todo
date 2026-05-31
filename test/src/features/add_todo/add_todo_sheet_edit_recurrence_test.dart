import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/domain/category.dart';
import 'package:solo_todo/src/domain/group.dart';
import 'package:solo_todo/src/domain/recurrence.dart';
import 'package:solo_todo/src/domain/todo.dart';
import 'package:solo_todo/src/features/add_todo/add_todo_sheet.dart';
import 'package:solo_todo/src/features/category/categories_controller.dart';
import 'package:solo_todo/src/features/category/groups_controller.dart';
import 'package:solo_todo/src/features/outline/tree_providers.dart';

void main() {
  Todo master() => Todo(
    id: 'm1',
    title: '매주 정산',
    category: Category.work,
    dueAt: DateTime(2026, 1, 5, 9),
    doneAt: null,
    createdAt: DateTime(2026, 1, 5),
    updatedAt: DateTime(2026, 1, 5),
    seriesId: 'm1',
    recurrenceRule: const RecurrenceRule(freq: RecurrenceFreq.weekly).encode(),
    recurrenceEndAt: DateTime(2026, 12, 31),
    isSeriesMaster: true,
  );

  Todo instance() => Todo(
    id: 'm1#20260105',
    title: '매주 정산',
    category: Category.work,
    dueAt: DateTime(2026, 1, 5, 9),
    doneAt: null,
    createdAt: DateTime(2026, 1, 5),
    updatedAt: DateTime(2026, 1, 5),
    seriesId: 'm1',
  );

  Todo plain() => Todo(
    id: 'p',
    title: '일반 할일',
    category: Category.work,
    dueAt: DateTime(2026, 1, 5, 9),
    doneAt: null,
    createdAt: DateTime(2026, 1, 5),
    updatedAt: DateTime(2026, 1, 5),
  );

  Future<void> mountEdit(
    WidgetTester tester,
    Todo editing,
    List<Todo> all,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith(
            (_) => Stream.value(Category.builtinSeeds),
          ),
          groupsProvider.overrideWith((_) => Stream.value(<Group>[])),
          allTodosProvider.overrideWith((_) => Stream.value(all)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AddTodoSheet(
                onSubmit: (_) {},
                onUpdate: (_) {},
                initialTodo: editing,
                initialCategory: editing.category,
                now: () => DateTime(2026, 1, 5, 9),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  const info = ValueKey('edit-recurrence-info');
  const stop = ValueKey('edit-recurrence-stop');

  testWidgets('반복 인스턴스 편집 → 규칙 요약 + 반복 중지 버튼', (tester) async {
    await mountEdit(tester, instance(), [master(), instance()]);
    expect(find.byKey(info), findsOneWidget);
    expect(find.byKey(stop), findsOneWidget);
    // 마스터 규칙 요약(매주 · 2026.12.31 까지)이 표시된다.
    expect(find.textContaining('매주'), findsOneWidget);
    expect(find.textContaining('2026.12.31'), findsOneWidget);
    // 추가 모드 전용 반복 입력 칩은 편집 모드에서 안 보인다.
    expect(find.byKey(const ValueKey('recur-freq-none')), findsNothing);
  });

  testWidgets('일반(비반복) 항목 편집 → 반복 정보 없음', (tester) async {
    await mountEdit(tester, plain(), [plain()]);
    expect(find.byKey(info), findsNothing);
    expect(find.byKey(stop), findsNothing);
  });

  testWidgets('반복 중지 탭 → 확인 다이얼로그', (tester) async {
    await mountEdit(tester, instance(), [master(), instance()]);
    await tester.tap(find.byKey(stop));
    await tester.pumpAndSettle();
    // 다이얼로그 노출 — 타이틀 + 본문 + 확정 버튼.
    expect(find.text('반복 중지'), findsWidgets);
    expect(find.textContaining('반복을 멈출까요'), findsOneWidget);
  });
}
