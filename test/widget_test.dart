import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/app/app.dart';

void main() {
  testWidgets('App boots and renders Solo Todo placeholder', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SoloTodoApp()));
    expect(find.text('Solo Todo'), findsOneWidget);
  });
}
