import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/core/theme.dart';
import 'package:solo_todo/src/ui/app_shell.dart' show SidebarItem;
import 'package:solo_todo/src/ui/destination.dart';

/// 사이드바 아이템의 키보드 focus ring 동작.
///
/// 비전: 데스크탑 메인 (macOS) — 키보드 사용 빈도 높음. 마우스만 쓰는 사용자에게는
/// hover splash 만으로 충분하지만, 키보드 traversal 시에는 outline ring 으로 현재
/// focus 위치를 분명히 표시해야 함.
void main() {
  Widget mount({required bool selected, bool autofocus = false}) {
    return MaterialApp(
      theme: AppTheme.mobileLight(),
      home: Scaffold(
        body: SidebarItem(
          destination: AppDestination.all.first,
          selected: selected,
          onTap: () {},
          autofocus: autofocus,
        ),
      ),
    );
  }

  RoundedRectangleBorder sidebarShape(WidgetTester tester) {
    // SidebarItem 의 외곽 Material 이 shape (BorderSide width = ring 두께) 를 갖는다.
    // Tooltip 안의 Material 만 대상 (Scaffold/Material app 의 baseline Material 제외).
    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(Tooltip),
        matching: find.byType(Material),
      ),
    );
    return material.shape! as RoundedRectangleBorder;
  }

  testWidgets('초기 (focus 없음) — outline 없음', (tester) async {
    await tester.pumpWidget(mount(selected: false));
    await tester.pump();

    expect(
      sidebarShape(tester).side.width,
      0,
      reason: 'focus 가 들어오지 않은 sidebar item 은 BorderSide 가 0',
    );
  });

  testWidgets('selected 만 — outline 없음 (focus 받기 전까지)', (tester) async {
    await tester.pumpWidget(mount(selected: true));
    await tester.pump();

    expect(
      sidebarShape(tester).side.width,
      0,
      reason: 'selected 상태와 focus ring 은 독립 — 키보드 focus 가 없으면 ring 도 없음',
    );
  });

  testWidgets('키보드 focus 들어옴 → outline (BorderSide.width > 0)', (tester) async {
    await tester.pumpWidget(mount(selected: false, autofocus: true));
    await tester.pump(); // autofocus 첫 frame
    await tester.pump(); // onFocusChange setState 반영

    final side = sidebarShape(tester).side;
    expect(
      side.width,
      greaterThan(0),
      reason: 'autofocus 로 focus 받은 sidebar item 은 outline 이 노출',
    );
    expect(
      side.color.a,
      greaterThan(0),
      reason: 'outline 색은 visible (alpha > 0)',
    );
  });

  testWidgets('selected + focus → outline + selected 배경 모두 적용', (tester) async {
    await tester.pumpWidget(mount(selected: true, autofocus: true));
    await tester.pump();
    await tester.pump();

    expect(sidebarShape(tester).side.width, greaterThan(0));

    // selected 의 배경 (primary 12% alpha) 도 같이 있어야 — 두 상태가 동시 표현.
    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(Tooltip),
        matching: find.byType(Material),
      ),
    );
    expect(material.color, isNotNull);
    expect(
      material.color!.a,
      greaterThan(0),
      reason: 'selected 상태의 primary tint 배경 유지',
    );
  });
}
