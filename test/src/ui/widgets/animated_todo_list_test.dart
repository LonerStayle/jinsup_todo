import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/domain/category.dart';
import 'package:solo_todo/src/domain/todo.dart';
import 'package:solo_todo/src/ui/widgets/animated_todo_list.dart';

/// AnimatedTodoSliver 의 id-based diff 가 추가/삭제/위치이동 시 올바른 final state 로
/// 수렴하는지 검증. 애니메이션 자체 (motionMid) 는 pumpAndSettle 로 흘려보낸 뒤
/// 마지막 표시 상태만 본다.
void main() {
  Todo todo({required String id, String? title, DateTime? doneAt}) => Todo(
    id: id,
    title: title ?? 'todo-$id',
    category: Category.daily,
    dueAt: null,
    doneAt: doneAt,
    createdAt: DateTime.utc(2026, 5, 27, 1),
    updatedAt: DateTime.utc(2026, 5, 27, 1),
    calendarEventId: null,
  );

  Future<void> mountWith(WidgetTester tester, List<Todo> initial) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              AnimatedTodoSliver(
                todos: initial,
                onToggle: (_) {},
                onDelete: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> rebuildWith(WidgetTester tester, List<Todo> next) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              AnimatedTodoSliver(
                todos: next,
                onToggle: (_) {},
                onDelete: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('초기 list → 모든 tile 표시', (tester) async {
    await mountWith(tester, [todo(id: 'a'), todo(id: 'b'), todo(id: 'c')]);
    await tester.pumpAndSettle();

    expect(find.text('todo-a'), findsOneWidget);
    expect(find.text('todo-b'), findsOneWidget);
    expect(find.text('todo-c'), findsOneWidget);
  });

  testWidgets('새 todo 추가 → list 에 노출', (tester) async {
    await mountWith(tester, [todo(id: 'a'), todo(id: 'b')]);
    await tester.pumpAndSettle();

    await rebuildWith(tester, [todo(id: 'a'), todo(id: 'b'), todo(id: 'c')]);

    expect(find.text('todo-a'), findsOneWidget);
    expect(find.text('todo-b'), findsOneWidget);
    expect(find.text('todo-c'), findsOneWidget);
  });

  testWidgets('todo 삭제 → list 에서 사라짐', (tester) async {
    await mountWith(tester, [todo(id: 'a'), todo(id: 'b'), todo(id: 'c')]);
    await tester.pumpAndSettle();

    await rebuildWith(tester, [todo(id: 'a'), todo(id: 'c')]);

    expect(find.text('todo-a'), findsOneWidget);
    expect(find.text('todo-b'), findsNothing);
    expect(find.text('todo-c'), findsOneWidget);
  });

  testWidgets('체크 토글로 위치 이동 — 같은 todo 가 새 위치에 그대로 보임', (tester) async {
    // 초기: a(미체크), b(미체크), c(미체크). watchAll 정렬 (미체크 먼저).
    await mountWith(tester, [todo(id: 'a'), todo(id: 'b'), todo(id: 'c')]);
    await tester.pumpAndSettle();

    // a 를 체크 → 미체크 그룹에서 빠져 체크 그룹 끝으로 이동.
    await rebuildWith(tester, [
      todo(id: 'b'),
      todo(id: 'c'),
      todo(id: 'a', doneAt: DateTime(2026, 5, 27, 9)),
    ]);

    expect(find.text('todo-a'), findsOneWidget);
    expect(find.text('todo-b'), findsOneWidget);
    expect(find.text('todo-c'), findsOneWidget);
  });

  testWidgets('내용 변경 (title 수정) — 같은 위치 그대로, 새 title 노출', (tester) async {
    await mountWith(tester, [todo(id: 'a', title: '원래 제목')]);
    await tester.pumpAndSettle();

    await rebuildWith(tester, [todo(id: 'a', title: '바뀐 제목')]);

    expect(find.text('바뀐 제목'), findsOneWidget);
    expect(find.text('원래 제목'), findsNothing);
  });

  testWidgets('전부 삭제 → 빈 list', (tester) async {
    await mountWith(tester, [todo(id: 'a'), todo(id: 'b')]);
    await tester.pumpAndSettle();

    await rebuildWith(tester, []);

    expect(find.text('todo-a'), findsNothing);
    expect(find.text('todo-b'), findsNothing);
  });
}
