import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/core/theme.dart';
import 'package:solo_todo/src/domain/category.dart';
import 'package:solo_todo/src/domain/todo.dart';
import 'package:solo_todo/src/ui/widgets/todo_tile.dart';

void main() {
  Todo make({
    String id = 'a',
    String title = '회사 보고',
    Category category = Category.work,
    DateTime? dueAt,
    DateTime? doneAt,
    DateTime? endAt,
    bool isAllDay = false,
    String timeAnchor = 'start',
    TodoType type = TodoType.task,
  }) => Todo(
    id: id,
    title: title,
    category: category,
    dueAt: dueAt,
    doneAt: doneAt,
    createdAt: DateTime.utc(2026, 5, 27, 9),
    updatedAt: DateTime.utc(2026, 5, 27, 9),
    calendarEventId: null,
    type: type,
    endAt: endAt,
    isAllDay: isAllDay,
    timeAnchor: timeAnchor,
  );

  Future<void> mount(WidgetTester tester, Todo todo, {VoidCallback? onToggle}) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.mobileLight(),
        home: Scaffold(
          body: TodoTile(todo: todo, onToggle: onToggle),
        ),
      ),
    );
  }

  testWidgets('task 타입 — 체크 아이콘 표시 (radio_button_unchecked)', (tester) async {
    await mount(tester, make());
    expect(find.byKey(const ValueKey('todo-tile-check')), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
    expect(find.byKey(const ValueKey('todo-tile-note-leading')), findsNothing);
  });

  testWidgets('task 체크됨 → check_circle_rounded', (tester) async {
    await mount(tester, make(doneAt: DateTime.utc(2026, 5, 27, 10)));
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });

  testWidgets('task — onToggle 콜백 연결', (tester) async {
    var toggled = 0;
    await mount(tester, make(), onToggle: () => toggled++);
    await tester.tap(find.byKey(const ValueKey('todo-tile-check')));
    await tester.pump();
    expect(toggled, 1);
  });

  testWidgets('note 타입 — 체크 아이콘 대신 sticky_note 아이콘', (tester) async {
    await mount(tester, make(type: TodoType.note, title: '→ KV 캐싱'));
    expect(
      find.byKey(const ValueKey('todo-tile-note-leading')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.sticky_note_2_outlined), findsOneWidget);
    // 체크 IconButton 자체가 없어야 함.
    expect(find.byKey(const ValueKey('todo-tile-check')), findsNothing);
    expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
  });

  testWidgets('note 타입 — 제목이 italic 으로 표시 (메모 시각 구분)', (tester) async {
    await mount(tester, make(type: TodoType.note, title: 'memo'));
    final text = tester.widget<Text>(find.text('memo'));
    expect(text.style?.fontStyle, FontStyle.italic);
  });

  testWidgets('note 타입 + dueAt 있어도 시간 노출 X (note 는 일정 무관)', (tester) async {
    await mount(
      tester,
      make(type: TodoType.note, dueAt: DateTime(2026, 5, 27, 14, 30)),
    );
    expect(find.text('14:30'), findsNothing);
  });

  testWidgets('하루종일 task — 시간(00:00) 미출력, 날짜만 표시', (tester) async {
    await mount(tester, make(dueAt: DateTime(2026, 5, 27), isAllDay: true));
    expect(find.text('5/27'), findsOneWidget);
    expect(find.text('00:00'), findsNothing);
    expect(find.textContaining('오전'), findsNothing);
  });

  testWidgets('시작시간 task — "시작 M/D HH:mm"', (tester) async {
    await mount(tester, make(dueAt: DateTime(2026, 5, 27, 14, 30)));
    expect(find.text('시작 5/27 14:30'), findsOneWidget);
  });

  testWidgets('기간 task — "M/D ~ M/D"', (tester) async {
    await mount(
      tester,
      make(
        dueAt: DateTime(2026, 5, 27),
        endAt: DateTime(2026, 5, 30),
        isAllDay: true,
      ),
    );
    expect(find.text('5/27 ~ 5/30'), findsOneWidget);
  });

  testWidgets('task — onToggle null 이면 IconButton.onPressed null (disabled)', (
    tester,
  ) async {
    // 일반 task tile 의 onToggle 가 미지정인 경우 IconButton 이 비활성.
    await mount(tester, make());
    final btn = tester.widget<IconButton>(
      find.byKey(const ValueKey('todo-tile-check')),
    );
    expect(btn.onPressed, isNull);
  });
}
