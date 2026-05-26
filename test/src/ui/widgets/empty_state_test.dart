import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/core/theme.dart';
import 'package:solo_todo/src/ui/widgets/empty_state.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.mobileLight(),
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('title 만 — icon + title 노출, subtitle 없음', (tester) async {
    await pump(tester, const EmptyState(icon: Icons.check, title: '비어 있어요'));
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.text('비어 있어요'), findsOneWidget);
  });

  testWidgets('subtitle 주면 함께 노출', (tester) async {
    await pump(
      tester,
      const EmptyState(icon: Icons.add, title: '아직 없어요', subtitle: '추가해 보세요'),
    );
    expect(find.text('추가해 보세요'), findsOneWidget);
  });

  testWidgets('tone 지정 시 아이콘 색이 그 tone', (tester) async {
    await pump(
      tester,
      const EmptyState(
        icon: Icons.flag,
        title: '장기 목표 없음',
        tone: Color(0xFFEF4444),
      ),
    );
    final iconWidget = tester.widget<Icon>(find.byIcon(Icons.flag));
    expect(iconWidget.color, const Color(0xFFEF4444));
  });
}
