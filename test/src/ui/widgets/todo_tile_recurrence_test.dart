import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/domain/category.dart';
import 'package:solo_todo/src/domain/todo.dart';
import 'package:solo_todo/src/ui/widgets/todo_tile.dart';

void main() {
  Todo make({
    String id = 't1',
    String? seriesId,
    TodoType type = TodoType.task,
  }) => Todo(
    id: id,
    title: '비타민',
    category: Category.work,
    dueAt: DateTime(2026, 1, 5),
    doneAt: null,
    createdAt: DateTime(2026, 1, 5),
    updatedAt: DateTime(2026, 1, 5),
    type: type,
    seriesId: seriesId,
  );

  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  const recurIcon = ValueKey('todo-tile-recurring-icon');
  const badge = ValueKey('todo-tile-series-badge');

  testWidgets('일반 todo — 반복 아이콘/배지 없음', (tester) async {
    await tester.pumpWidget(host(TodoTile(todo: make())));
    expect(find.byKey(recurIcon), findsNothing);
    expect(find.byKey(badge), findsNothing);
  });

  testWidgets('반복 시리즈 항목 — 반복 아이콘 표시 (FR-7)', (tester) async {
    await tester.pumpWidget(host(TodoTile(todo: make(seriesId: 's1'))));
    expect(find.byKey(recurIcon), findsOneWidget);
  });

  testWidgets('note 는 반복 아이콘 미표시', (tester) async {
    await tester.pumpWidget(
      host(
        TodoTile(
          todo: make(seriesId: 's1', type: TodoType.note),
        ),
      ),
    );
    expect(find.byKey(recurIcon), findsNothing);
  });

  testWidgets('hiddenSeriesCount>0 — "외 N건" 배지 표시 (FR-4)', (tester) async {
    await tester.pumpWidget(
      host(TodoTile(todo: make(seriesId: 's1'), hiddenSeriesCount: 2)),
    );
    expect(find.byKey(badge), findsOneWidget);
    expect(find.textContaining('2건'), findsOneWidget);
  });

  testWidgets('hiddenSeriesCount=0 — 배지 없음', (tester) async {
    await tester.pumpWidget(host(TodoTile(todo: make(seriesId: 's1'))));
    expect(find.byKey(badge), findsNothing);
  });
}
