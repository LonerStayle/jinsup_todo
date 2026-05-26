import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/app/app.dart';

void main() {
  testWidgets('App boots and shows AppShell with Solo Todo brand', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: SoloTodoApp()));
    // macOS desktop 분기에서는 사이드바에 "Solo Todo" 가, Android 분기에서는
    // 메인 영역의 destination label 만 보인다. 호스트 (macOS) 기준 사이드바가 켜진다.
    expect(find.text('Solo Todo'), findsOneWidget);
    // 오늘 destination 이 기본 선택 — 메인 영역에 "오늘" 라벨이 있다.
    expect(find.text('오늘'), findsAtLeastNWidgets(1));
  });
}
