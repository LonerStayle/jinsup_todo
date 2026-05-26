import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers.dart';
import '../syncing_todo_repository.dart';
import '../todo_repository.dart';
import '../../features/auth/auth_providers.dart';
import 'last_write_wins.dart';
import 'supabase_provider.dart';
import 'supabase_todos_api.dart';

/// Supabase `todos` 테이블의 변경 (INSERT/UPDATE/DELETE) 을 구독해
/// 로컬 [TodoRepository] 에 반영. user_id 필터로 본인 row 만.
///
/// 충돌 해소 (updated_at 기반 last-write-wins) 는 다음 task 에서 도입.
/// 지금은 원격 변경 → local upsert/delete 만.
class SupabaseRealtimeSync {
  SupabaseRealtimeSync({
    required this.client,
    required this.api,
    required this.localRepo,
    required this.userId,
  });

  final SupabaseClient client;
  final RemoteTodosApi api;
  final TodoRepository localRepo;
  final String userId;

  RealtimeChannel? _channel;
  Timer? _flushTimer;

  Future<void> start() async {
    try {
      // 1) 초기 풀백 — 원격 todos 를 local 로 복제. LWW 로 local 이 더 최신이면 skip.
      final remoteAll = await api.fetchAll(userId);
      for (final remote in remoteAll) {
        final local = await localRepo.getById(remote.id);
        if (LastWriteWins.remoteWins(local, remote)) {
          await localRepo.upsert(remote);
        }
      }

      // 2) 오프라인 동안 쌓였을 outbox 즉시 flush.
      await _flushIfSyncing();

      // 3) 변경 구독.
      _channel = client
          .channel('solo_todo_todos:$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'solo_todo_todos',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: _handle,
          )
          .subscribe();

      // 4) 주기 retry — 일시 단절 후 자동 복구. 30 초마다 flush 시도 (큐 비어 있으면 no-op).
      _flushTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _flushIfSyncing(),
      );
    } catch (e) {
      debugPrint('[solo_todo] Supabase realtime 구독 실패: $e');
    }
  }

  Future<void> _flushIfSyncing() async {
    final repo = localRepo;
    if (repo is SyncingTodoRepository) {
      await repo.flushPending();
    }
  }

  Future<void> _handle(PostgresChangePayload payload) async {
    try {
      switch (payload.eventType) {
        case PostgresChangeEvent.insert:
        case PostgresChangeEvent.update:
          final remote = api.todoFromRow(payload.newRecord);
          final local = await localRepo.getById(remote.id);
          // LWW: local 이 더 최신 (사용자가 방금 수정) 이면 stale remote skip.
          if (LastWriteWins.remoteWins(local, remote)) {
            await localRepo.upsert(remote);
          }
          break;
        case PostgresChangeEvent.delete:
          final id = payload.oldRecord['id'] as String?;
          if (id != null) await localRepo.deleteById(id);
          break;
        case PostgresChangeEvent.all:
          // postgres_changes API 는 .all 으로 등록해도 callback 에는 구체 event 만 옴.
          break;
      }
    } catch (e) {
      debugPrint('[solo_todo] realtime payload 처리 실패: $e');
    }
  }

  Future<void> stop() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    final c = _channel;
    if (c == null) return;
    try {
      await client.removeChannel(c);
    } catch (_) {
      // 종료 단계 — 무시.
    }
    _channel = null;
  }
}

/// 인증된 user 가 있을 때만 [SupabaseRealtimeSync] 를 활성화하는 lifecycle provider.
///
/// 누군가 `ref.watch(supabaseRealtimeSyncProvider)` 호출해야 init 된다 (AppShell 이 watch).
final supabaseRealtimeSyncProvider = Provider<SupabaseRealtimeSync?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final api = ref.watch(supabaseTodosApiProvider);
  final user = ref.watch(currentUserProvider);
  if (client == null || api == null || user == null) return null;

  final sync = SupabaseRealtimeSync(
    client: client,
    api: api,
    localRepo: ref.watch(todoRepositoryProvider),
    userId: user.id,
  );
  sync.start();
  ref.onDispose(sync.stop);
  return sync;
});
