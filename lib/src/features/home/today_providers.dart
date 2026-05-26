import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/day_boundary_provider.dart';
import '../../data/providers.dart';
import '../../domain/policies/carryover_policy.dart';
import '../../domain/todo.dart';

/// 오늘 화면에 보일 todos (visibility 적용된 list).
///
/// [currentDayProvider] 를 watch 해 자정마다 자동 re-subscribe → 새 now() 기준 필터
/// (= 미체크 자동 이월 + 어제 체크된 항목 자동 hide 가 자정에 발화).
final watchTodayTodosProvider = StreamProvider<List<Todo>>((ref) {
  ref.watch(currentDayProvider);
  final repo = ref.watch(todoRepositoryProvider);
  final now = ref.watch(nowProvider);
  return repo.watchToday(now);
});

/// 오늘 화면 visible todos 중 미체크 항목의 개수 (트레이 카운트 표시용).
final undoneTodayCountProvider = Provider<int>((ref) {
  final asyncTodos = ref.watch(watchTodayTodosProvider);
  return asyncTodos.maybeWhen(
    data: (todos) => todos.where((t) => !t.isDone).length,
    orElse: () => 0,
  );
});

/// 어제 이전에서 이월된 미체크 항목의 개수 (배너 표시용).
final carryoverCountProvider = Provider<int>((ref) {
  // currentDayProvider 가 자정 갱신 시 같이 재계산되도록 transitively 의존.
  // watchTodayTodosProvider 가 이미 watch 하므로 별도 watch 불필요.
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
