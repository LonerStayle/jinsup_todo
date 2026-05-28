import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/ui/app_shell.dart' show isFocusInEditableText;

void main() {
  testWidgets('TextField focus 가 아닐 때 → isFocusInEditableText == false', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('hello'))),
    );
    expect(isFocusInEditableText(), isFalse);
  });

  testWidgets('TextField focus 일 때 → isFocusInEditableText == true', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TextField(controller: controller, focusNode: focusNode),
        ),
      ),
    );

    focusNode.requestFocus();
    await tester.pump();

    expect(
      isFocusInEditableText(),
      isTrue,
      reason: 'TextField focus 시 _ShortcutsHost 의 0~5 키 capture 가 차단되어야 함',
    );
  });
}
