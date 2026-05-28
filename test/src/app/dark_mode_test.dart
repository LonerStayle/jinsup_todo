import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/app/app.dart';
import 'package:solo_todo/src/core/theme.dart';
import 'package:solo_todo/src/data/providers.dart';
import 'package:solo_todo/src/domain/category.dart';
import 'package:solo_todo/src/domain/todo.dart';
import 'package:solo_todo/src/features/category/categories_controller.dart';
import 'package:solo_todo/src/features/category/category_providers.dart';
import 'package:solo_todo/src/features/home/today_providers.dart';
import 'package:solo_todo/src/features/outline/tree_providers.dart';

/// 시스템 다크모드 추종 — MaterialApp.themeMode = ThemeMode.system 이고
/// AppTheme.mobileLight() / mobileDark() 가 정의되어 있으므로 host OS 의 dark/light
/// 변경 시 자동 갱신된다. 여기서는 platformBrightness override 로 두 분기 모두 검증.
void main() {
  Widget app() => ProviderScope(
    overrides: [
      watchTodayTodosProvider.overrideWith((_) => Stream.value(<Todo>[])),
      watchTodosByCategoryProvider.overrideWith(
        (_, _) => Stream.value(<Todo>[]),
      ),
      outboxCountProvider.overrideWith((_) => Stream<int>.value(0)),
      // v1.1 — breadcrumb 가 allTodosProvider 를 watch.
      allTodosProvider.overrideWith((_) => Stream.value(<Todo>[])),
      // v1.2 — AppShell 이 categoriesProvider 를 watch.
      categoriesProvider.overrideWith(
        (_) => Stream.value(Category.builtinSeeds),
      ),
    ],
    child: const SoloTodoApp(),
  );

  testWidgets('platformBrightness = light → ThemeData.brightness = light', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(app());
    await tester.pump();

    final BuildContext ctx = tester.element(find.byType(Scaffold).first);
    final theme = Theme.of(ctx);
    expect(theme.brightness, Brightness.light);
    expect(theme.scaffoldBackgroundColor, AppPalette.lightBg);
  });

  testWidgets('platformBrightness = dark → ThemeData.brightness = dark', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(app());
    await tester.pump();

    final BuildContext ctx = tester.element(find.byType(Scaffold).first);
    final theme = Theme.of(ctx);
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, AppPalette.darkBg);
  });
}
