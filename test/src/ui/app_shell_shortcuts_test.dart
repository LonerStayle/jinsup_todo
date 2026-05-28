import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/core/theme.dart';
import 'package:solo_todo/src/data/providers.dart';
import 'package:solo_todo/src/domain/todo.dart';
import 'package:solo_todo/src/features/category/category_providers.dart';
import 'package:solo_todo/src/features/home/today_providers.dart';
import 'package:solo_todo/src/ui/app_shell.dart';

void main() {
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // 모든 stream provider 를 빈 stream 으로 override 해서 Drift 의존 + timer leak 제거.
          watchTodayTodosProvider.overrideWith((_) => Stream.value(<Todo>[])),
          watchTodosByCategoryProvider.overrideWith(
            (_, _) => Stream.value(<Todo>[]),
          ),
          outboxCountProvider.overrideWith((_) => Stream<int>.value(0)),
        ],
        child: MaterialApp(
          theme: AppTheme.mobileLight(),
          home: const AppShell(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('초기 진입은 Today (오늘 헤더 표시)', (tester) async {
    await pump(tester);
    expect(find.text('오늘'), findsAtLeastNWidgets(1));
  });

  testWidgets('숫자 1 키 → work 카테고리 헤더 노출', (tester) async {
    await pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.pump();
    expect(find.text('회사 할일'), findsAtLeastNWidgets(1));
  });

  testWidgets('숫자 3 키 → daily 카테고리 헤더 노출', (tester) async {
    await pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    await tester.pump();
    expect(find.text('일상'), findsAtLeastNWidgets(1));
  });

  testWidgets('숫자 5 → idea 로 이동 후 0 → Today 복귀', (tester) async {
    await pump(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.digit5);
    await tester.pump();
    expect(find.text('아이디어'), findsAtLeastNWidgets(1));

    await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
    await tester.pump();
    expect(find.text('오늘'), findsAtLeastNWidgets(1));
  });

  testWidgets('v1.1 — 숫자 6 → Outline 화면 (전체보기) 노출', (tester) async {
    await pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit6);
    await tester.pump();
    expect(find.text('전체보기 (Outline)'), findsAtLeastNWidgets(1));
  });
}
