import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/domain/category.dart';
import 'package:solo_todo/src/domain/recurrence.dart';
import 'package:solo_todo/src/domain/todo.dart';
import 'package:solo_todo/src/features/outline/tree_providers.dart';
import 'package:solo_todo/src/features/recurrence/recurrence_manage_screen.dart';

Todo _master() => Todo(
  id: 'm1',
  title: '매주 정산',
  category: Category.work,
  dueAt: DateTime(2026, 1, 5, 9),
  doneAt: null,
  createdAt: DateTime(2026, 1, 5),
  updatedAt: DateTime(2026, 1, 5),
  seriesId: 'm1',
  recurrenceRule: const RecurrenceRule(freq: RecurrenceFreq.weekly).encode(),
  isSeriesMaster: true,
);

void main() {
  // allTodosProvider 를 Stream.value 로 override — 실제 Drift 의존 + timer leak 회피.
  Widget host(List<Todo> all) => ProviderScope(
    overrides: [allTodosProvider.overrideWith((_) => Stream.value(all))],
    child: const MaterialApp(home: RecurrenceManageScreen()),
  );

  testWidgets('마스터 없으면 빈 상태', (tester) async {
    await tester.pumpWidget(host(const []));
    await tester.pump();
    expect(find.text('반복 중인 할 일이 없어요'), findsOneWidget);
  });

  testWidgets('마스터 있으면 카드 + 규칙 요약 + 반복중지 버튼', (tester) async {
    await tester.pumpWidget(host([_master()]));
    await tester.pump();

    expect(find.text('매주 정산'), findsOneWidget);
    expect(find.text('매주'), findsOneWidget);
    expect(find.byKey(const ValueKey('recur-stop-m1')), findsOneWidget);
  });
}
