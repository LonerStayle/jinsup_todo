import '../../domain/todo.dart';

/// 동일 id 의 두 Todo 사본 (local / remote) 중 어느 쪽을 채택할지 결정.
///
/// updated_at 기반 last-write-wins:
///   - local 이 null (아직 못 받은 row) → remote 채택
///   - remote.updatedAt > local.updatedAt → remote 채택
///   - remote.updatedAt == local.updatedAt → 동률, remote 채택 (idempotent)
///   - remote.updatedAt < local.updatedAt → local 이 최신, remote stale → skip
class LastWriteWins {
  const LastWriteWins._();

  static bool remoteWins(Todo? local, Todo remote) {
    if (local == null) return true;
    return !remote.updatedAt.isBefore(local.updatedAt);
  }
}
