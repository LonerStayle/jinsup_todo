import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/app/app.dart';
import 'package:solo_todo/src/data/providers.dart';
import 'package:solo_todo/src/domain/category.dart';
import 'package:solo_todo/src/domain/group.dart';
import 'package:solo_todo/src/domain/todo.dart';
import 'package:solo_todo/src/features/category/categories_controller.dart';
import 'package:solo_todo/src/features/category/groups_controller.dart';
import 'package:solo_todo/src/features/home/today_providers.dart';
import 'package:solo_todo/src/features/outline/tree_providers.dart';

void main() {
  testWidgets('App boots — Solo Todo brand + 오늘 헤더 (smoke)', (tester) async {
    // 실제 Drift DB 대신 빈 Todo stream 주입 — 빠르고 timer leak 없음.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          watchTodayTodosProvider.overrideWith((_) => Stream.value(<Todo>[])),
          recurrenceMaterializerProvider.overrideWith((_) {}),
          outboxCountProvider.overrideWith((_) => Stream<int>.value(0)),
          // v1.1 — HomeScreen breadcrumb 가 allTodosProvider 를 watch.
          allTodosProvider.overrideWith((_) => Stream.value(<Todo>[])),
          // v1.2 — AppShell 이 categoriesProvider 를 watch (sidebar dynamic).
          categoriesProvider.overrideWith(
            (_) => Stream.value(Category.builtinSeeds),
          ),
          // v1.3 — AppShell 이 groupsProvider 를 watch (사이드바 그룹 섹션).
          groupsProvider.overrideWith((_) => Stream.value(<Group>[])),
        ],
        child: const SoloTodoApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Solo Todo'), findsOneWidget);
    expect(find.text('오늘'), findsAtLeastNWidgets(1));
  });
}
