import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/todo_repository.dart';
import '../../domain/todo.dart';

/// Todo 한 건에 대한 도메인 액션 (체크 토글 / 삭제 / 카테고리 변경 등).
///
/// 로컬 Drift 의존이므로 upsert/delete 는 거의 즉시 완료된다 (수 ms).
/// Drift watch stream 이 자동으로 UI 갱신 — 별도 optimistic state 관리 불필요.
/// 비전상 "낙관적 업데이트 (UI 먼저)" 는 추후 원격 (Supabase) 으로 확장될 때
/// 의미가 커진다.
class TodoActionsController {
  TodoActionsController(this._repo, this._now);

  final TodoRepository _repo;
  final DateTime Function() _now;

  /// 체크 상태를 토글. 미체크 → 체크, 체크 → 미체크. updatedAt + doneAt 갱신.
  Future<Todo> toggle(Todo todo) async {
    final updated = todo.toggleDone(now: _now);
    await _repo.upsert(updated);
    return updated;
  }
}

final todoActionsProvider = Provider<TodoActionsController>(
  (ref) => TodoActionsController(
    ref.watch(todoRepositoryProvider),
    ref.watch(nowProvider),
  ),
);
