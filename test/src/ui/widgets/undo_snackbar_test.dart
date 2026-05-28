import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/core/theme.dart';
import 'package:solo_todo/src/ui/widgets/undo_snackbar.dart';

void main() {
  testWidgets('SnackBar + "되돌리기" 액션 노출, 탭하면 onUndo 호출 + 즉시 dismiss', (
    tester,
  ) async {
    var undone = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.mobileLight(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showUndoSnackbar(
                  context,
                  message: '항목을 삭제했어요',
                  onUndo: () => undone++,
                ),
                child: const Text('show'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('show'));
    await tester.pump(); // start frame
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('항목을 삭제했어요'), findsOneWidget);
    expect(find.text('되돌리기'), findsOneWidget);

    await tester.tap(find.text('되돌리기'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(undone, 1, reason: '되돌리기 액션이 onUndo 콜백을 호출해야 함');
    expect(find.text('항목을 삭제했어요'), findsNothing);
  });

  group('progress bar — 남은 undo 시간 시각 표시', () {
    Future<void> show(WidgetTester tester, {Duration? duration}) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.mobileLight(),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showUndoSnackbar(
                    context,
                    message: '삭제됨',
                    onUndo: () {},
                    duration: duration ?? const Duration(seconds: 5),
                  ),
                  child: const Text('show'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('show'));
      await tester.pump(); // start animation frame
    }

    testWidgets('SnackBar 표시 직후 progress 가 1.0 근처', (tester) async {
      await show(tester);
      // SnackBar 의 enter 애니메이션이 끝나지 않아도 progress widget 자체는 mount.
      // tween 의 begin = 1.0 → 첫 builder 호출에 value ≈ 1.0.
      await tester.pump();

      final progress = tester.widget<LinearProgressIndicator>(
        find.byKey(const ValueKey('undo-snackbar-progress')),
      );
      expect(progress.value, isNotNull);
      expect(progress.value!, closeTo(1.0, 0.05));
    });

    testWidgets('SnackBar duration 의 절반 지나면 progress ≈ 0.5', (tester) async {
      await show(tester, duration: const Duration(seconds: 4));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      final progress = tester.widget<LinearProgressIndicator>(
        find.byKey(const ValueKey('undo-snackbar-progress')),
      );
      expect(
        progress.value!,
        closeTo(0.5, 0.15),
        reason: 'linear curve 라 절반 시각엔 절반 value 근처',
      );
    });

    testWidgets('duration 끝 시점에 progress ≈ 0 (남은 시간 0)', (tester) async {
      await show(tester, duration: const Duration(seconds: 2));
      await tester.pump();
      // SnackBar 의 enter 애니메이션이 끝나도록 약간 흘림 + 절반 + 끝까지.
      await tester.pump(const Duration(milliseconds: 300)); // enter 끝
      await tester.pump(const Duration(seconds: 2)); // tween 끝

      // SnackBar 가 사라지기 전 마지막 frame 에선 progress widget 이 아직 트리에 있다.
      // 닫히는 시점은 framework 가 결정 — 우린 progress 값만 본다.
      final found = find.byKey(const ValueKey('undo-snackbar-progress'));
      if (found.evaluate().isNotEmpty) {
        final progress = tester.widget<LinearProgressIndicator>(found);
        expect(progress.value!, closeTo(0.0, 0.1));
      }
    });
  });
}
