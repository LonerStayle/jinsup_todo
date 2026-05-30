import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/core/theme.dart';
import 'package:solo_todo/src/domain/category.dart';
import 'package:solo_todo/src/domain/todo.dart';
import 'package:solo_todo/src/ui/widgets/todo_tile.dart';

/// §13-2 — TodoTile note 틴트 배경 + 3px accent 보더 (task 미적용) 검증.
void main() {
  Todo make({
    Category category = Category.work,
    TodoType type = TodoType.task,
  }) => Todo(
    id: 'a',
    title: 't',
    category: category,
    dueAt: null,
    doneAt: null,
    createdAt: DateTime.utc(2026, 5, 27, 9),
    updatedAt: DateTime.utc(2026, 5, 27, 9),
    calendarEventId: null,
    type: type,
  );

  Future<void> mount(
    WidgetTester tester,
    Todo todo, {
    Brightness brightness = Brightness.light,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: brightness == Brightness.dark
            ? AppTheme.mobileDark()
            : AppTheme.mobileLight(),
        home: Scaffold(body: TodoTile(todo: todo)),
      ),
    );
  }

  Card card(WidgetTester tester) =>
      tester.widget<Card>(find.byType(Card).first);
  Container colorbar(WidgetTester tester) => tester.widget<Container>(
    find.byKey(const ValueKey('todo-tile-colorbar')),
  );

  testWidgets('note(light) — Card 배경이 카테고리 틴트', (tester) async {
    await mount(tester, make(type: TodoType.note));
    expect(
      card(tester).color,
      NoteVisual.tint(Category.work, Brightness.light),
    );
  });

  testWidgets('note(dark) — Card 배경이 다크 틴트(더 진함)', (tester) async {
    await mount(tester, make(type: TodoType.note), brightness: Brightness.dark);
    expect(card(tester).color, NoteVisual.tint(Category.work, Brightness.dark));
  });

  testWidgets('note — 좌측 컬러바가 3px accent 보더로 대체', (tester) async {
    await mount(tester, make(type: TodoType.note, category: Category.idea));
    final bar = colorbar(tester);
    expect(bar.constraints?.maxWidth, NoteVisual.accentWidth);
    expect(
      (bar.decoration as BoxDecoration).color,
      NoteVisual.accent(Category.idea),
    );
  });

  testWidgets('task — Card 기본 surface(null) + 8px 카테고리 컬러바 유지', (tester) async {
    await mount(tester, make(type: TodoType.task, category: Category.daily));
    expect(card(tester).color, isNull);
    final bar = colorbar(tester);
    expect(bar.constraints?.maxWidth, 8);
    expect((bar.decoration as BoxDecoration).color, Category.daily.color);
  });
}
