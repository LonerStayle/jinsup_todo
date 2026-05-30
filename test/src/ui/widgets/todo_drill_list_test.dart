import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/core/theme.dart';
import 'package:solo_todo/src/domain/category.dart';
import 'package:solo_todo/src/domain/todo.dart';
import 'package:solo_todo/src/ui/widgets/todo_drill_list.dart';

void main() {
  Todo make({
    required String id,
    String title = 't',
    String? parentId,
    TodoType type = TodoType.task,
  }) => Todo(
    id: id,
    title: title,
    category: Category.work,
    dueAt: null,
    doneAt: null,
    createdAt: DateTime.utc(2026, 5, 30),
    updatedAt: DateTime.utc(2026, 5, 30),
    calendarEventId: null,
    parentId: parentId,
    type: type,
  );

  Future<void> mount(
    WidgetTester tester, {
    required List<Todo> items,
    required List<Todo> allTodos,
    void Function(Todo)? onDrillDown,
    void Function(Todo)? onEdit,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.mobileLight(),
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              TodoDrillListSliver(
                items: items,
                allTodos: allTodos,
                onDrillDown: onDrillDown ?? (_) {},
                onEdit: onEdit ?? (_) {},
                onToggle: (_) {},
                onAddChild: (_) {},
                onDelete: (_) {},
                onReorderSiblings: (_, _, _) {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('자식 있는 항목 탭 → onDrillDown 호출 (onEdit 아님)', (tester) async {
    final parent = make(id: 'p', title: '폴더');
    final child = make(id: 'c', parentId: 'p');
    Todo? drilled;
    Todo? edited;
    await mount(
      tester,
      items: [parent],
      allTodos: [parent, child],
      onDrillDown: (t) => drilled = t,
      onEdit: (t) => edited = t,
    );

    await tester.tap(find.text('폴더'));
    await tester.pump();

    expect(drilled?.id, 'p');
    expect(edited, isNull);
    // 드릴 배지 노출.
    expect(find.byKey(const ValueKey('todo-tile-drill-p')), findsOneWidget);
    expect(find.text('하위 1'), findsOneWidget);
  });

  testWidgets('leaf(자식 없음) 탭 → onEdit 호출 (onDrillDown 아님)', (tester) async {
    final leaf = make(id: 'l', title: '단일');
    Todo? drilled;
    Todo? edited;
    await mount(
      tester,
      items: [leaf],
      allTodos: [leaf],
      onDrillDown: (t) => drilled = t,
      onEdit: (t) => edited = t,
    );

    await tester.tap(find.text('단일'));
    await tester.pump();

    expect(edited?.id, 'l');
    expect(drilled, isNull);
    expect(find.byKey(const ValueKey('todo-tile-drill-l')), findsNothing);
  });
}
