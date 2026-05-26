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
}
