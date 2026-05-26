import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/policies/carryover_policy.dart';
import '../../domain/todo.dart';

/// 오늘 화면에 보일 todos (visibility 적용된 list).
final watchTodayTodosProvider = StreamProvider<List<Todo>>((ref) {
  final repo = ref.watch(todoRepositoryProvider);
  final now = ref.watch(nowProvider);
  return repo.watchToday(now);
});

/// 어제 이전에서 이월된 미체크 항목의 개수 (배너 표시용).
final carryoverCountProvider = Provider<int>((ref) {
  final asyncTodos = ref.watch(watchTodayTodosProvider);
  final nowFn = ref.watch(nowProvider);
  return asyncTodos.maybeWhen(
    data: (todos) {
      final now = nowFn();
      return todos
          .where((t) => CarryoverPolicy.shouldCarryOverToday(t, now))
          .length;
    },
    orElse: () => 0,
  );
});
