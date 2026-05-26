import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/app/app.dart';
import 'package:solo_todo/src/domain/todo.dart';
import 'package:solo_todo/src/features/home/today_providers.dart';

void main() {
  testWidgets('App boots — Solo Todo brand + 오늘 헤더 (smoke)', (tester) async {
    // 실제 Drift DB 대신 빈 Todo stream 주입 — 빠르고 timer leak 없음.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          watchTodayTodosProvider.overrideWith((_) => Stream.value(<Todo>[])),
        ],
        child: const SoloTodoApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Solo Todo'), findsOneWidget);
    expect(find.text('오늘'), findsAtLeastNWidgets(1));
  });
}
