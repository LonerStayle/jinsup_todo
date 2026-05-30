import '../../domain/todo.dart';

/// 동일 id 의 두 Todo 사본 (local / remote) 중 어느 쪽을 채택할지 결정.
///
/// updated_at 기반 last-write-wins. **strict `>`** — 동률 시 local 채택:
///
///   - local 이 null (아직 못 받은 row) → remote 채택
///   - remote.updatedAt > local.updatedAt → remote 채택
///   - remote.updatedAt == local.updatedAt → **local 채택 (self-overwrite 방지)**
///   - remote.updatedAt < local.updatedAt → local 이 최신, remote stale → skip
///
/// 동률 시 local 을 채택하는 이유:
///   1. 자기 self-receive 시 local row 와 동일 → skip 해도 idempotent
///   2. 빠른 mutation race 로 ms 동률이 발생해도 local 의 최신 의도가 보존됨
class LastWriteWins {
  const LastWriteWins._();

  static bool remoteWins(Todo? local, Todo remote) {
    if (local == null) return true;
    // 반드시 UTC 로 정규화해 비교한다. 한쪽이 local-naive (Z 없음), 다른 쪽이 UTC(Z)
    // 면 같은 시각도 timezone offset 만큼 어긋나 stale 가 최신으로 오판된다.
    return remote.updatedAt.toUtc().isAfter(local.updatedAt.toUtc());
  }
}
