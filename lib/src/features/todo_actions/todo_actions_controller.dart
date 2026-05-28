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

  /// id 기준 삭제. 호출자가 [restore] 로 되돌릴 수 있도록 원본은 호출자가 보관.
  Future<void> delete(Todo todo) => _repo.deleteById(todo.id);

  /// [delete] 로 지워진 Todo 를 그대로 복원 (id 동일, updatedAt 보존).
  /// Undo SnackBar 의 "되돌리기" 액션이 호출한다.
  Future<void> restore(Todo todo) => _repo.upsert(todo);

  /// v1.2 — 기존 todo 의 필드 수정 (title / description / category / dueAt / type).
  /// updatedAt 은 자동으로 [_now] 의 호출 시점 값으로 갱신 — LWW 동기화 호환.
  /// 호출자가 [updated] 의 updatedAt 을 미리 set 했다면 우선시 (테스트 결정성).
  Future<Todo> update(Todo updated) async {
    final synced = updated.copyWith(updatedAt: _now());
    await _repo.upsert(synced);
    return synced;
  }
}

final todoActionsProvider = Provider<TodoActionsController>(
  (ref) => TodoActionsController(
    ref.watch(todoRepositoryProvider),
    ref.watch(nowProvider),
  ),
);
