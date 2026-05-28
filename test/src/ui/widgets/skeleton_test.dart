import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/core/theme.dart';
import 'package:solo_todo/src/ui/widgets/skeleton.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.mobileLight(),
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('TodoListSkeleton 기본 4 개 tile + pulse', (tester) async {
    await pump(tester, const TodoListSkeleton());
    expect(find.byType(TodoTileSkeleton), findsNWidgets(4));
    // pulse 가 동작하는지 — animation tick 후 finish 안되도록 잠시 pump.
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(TodoTileSkeleton), findsNWidgets(4));
    // 무한 animation 이라 unmount 로 끊어줘야 tester 가 종료된다.
    await pump(tester, const SizedBox.shrink());
  });

  testWidgets('itemCount override', (tester) async {
    await pump(tester, const TodoListSkeleton(itemCount: 2));
    expect(find.byType(TodoTileSkeleton), findsNWidgets(2));
    await pump(tester, const SizedBox.shrink());
  });

  testWidgets('Visibility(visible: false) 로 가려진 채 mount/unmount 해도 leak 없음', (
    tester,
  ) async {
    // maintainAnimation 미지정(default false) → ticker 자동 mute + 자식 build skip.
    await pump(
      tester,
      const Visibility(visible: false, child: TodoListSkeleton(itemCount: 2)),
    );
    // build 가 안 됐으니 tile 도 0.
    expect(find.byType(TodoTileSkeleton), findsNothing);
    await pump(tester, const SizedBox.shrink());
  });
}
