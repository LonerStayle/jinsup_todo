import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/category.dart';
import '../../domain/group.dart';
import '../../domain/todo.dart';
import '../categories_repository.dart';
import '../groups_repository.dart';
import '../local/local_categories_repository.dart';
import '../local/local_groups_repository.dart';
import '../local/local_todo_repository.dart';
import '../providers.dart';
import '../syncing_todo_repository.dart';
import '../todo_repository.dart';
import '../../features/auth/auth_providers.dart';
import 'last_write_wins.dart';
import 'supabase_categories_api.dart';
import 'supabase_groups_api.dart';
import 'supabase_provider.dart';
import 'supabase_todos_api.dart';

/// Supabase `todos` 의 변경을 구독해 **로컬에만** 반영한다.
///
/// 중요 — [localApply] 는 반드시 **outbox 를 거치지 않는** repository 여야 한다
/// (예: [LocalTodoRepository]).
///
/// realtime 채널은 자기 자신의 push 결과 (INSERT/UPDATE/DELETE) 도 그대로 받는다.
/// 만약 [SyncingTodoRepository] 를 직접 주입하면 self-receive → outbox 재enqueue →
/// 또 다시 push → realtime 또 broadcast → **무한 루프**가 발생한다.
/// (체크가 풀리거나, 삭제가 되돌아오거나, 호출이 무한히 반복되는 증상으로 관측됨.)
///
/// outbox flush 가 필요하면 [flushOutbox] 콜백을 호출한다 (재연결 후 1회 + 30s 주기).
class SupabaseRealtimeSync {
  SupabaseRealtimeSync({
    required this.client,
    required this.api,
    required this.localApply,
    required this.flushOutbox,
    required this.userId,
    required this.categoriesApi,
    required this.categoriesApply,
    required this.groupsApi,
    required this.groupsApply,
  });

  /// 단위 테스트 전용 — channel subscribe / start 를 거치지 않고 apply* 메서드만 검증.
  @visibleForTesting
  SupabaseRealtimeSync.forApplyOnly({
    required this.api,
    required this.localApply,
    required this.flushOutbox,
    required this.userId,
    required this.categoriesApi,
    required this.categoriesApply,
    required this.groupsApi,
    required this.groupsApply,
  }) : client = null;

  final SupabaseClient? client;
  final RemoteTodosApi api;

  /// outbox 우회 — local-only repository. [SyncingTodoRepository] 금지.
  final TodoRepository localApply;

  /// outbox flush 트리거. realtime sync 가 직접 outbox 를 알지 않도록 콜백으로 분리.
  final Future<void> Function() flushOutbox;

  final String userId;

  // ---- categories / groups (cross-device 동기화) -------------------------
  // todos 와 동일 패턴. categories/groups 는 updatedAt 이 없어 LWW 대신 remote
  // upsert (원격 반영) 로 단순 적용.
  //
  // self-receive 무한 루프 주의 — [categoriesApply] / [groupsApply] 는 반드시
  // outbox 우회 (Local*Repository) 여야 한다. Syncing* 를 주입하면 self-broadcast →
  // outbox 재enqueue → 무한 push 루프.
  final RemoteCategoriesApi categoriesApi;
  final CategoriesRepository categoriesApply;
  final RemoteGroupsApi groupsApi;
  final GroupsRepository groupsApply;

  RealtimeChannel? _channel;
  RealtimeChannel? _categoriesChannel;
  RealtimeChannel? _groupsChannel;
  Timer? _flushTimer;

  Future<void> start() async {
    final c = client;
    if (c == null) {
      // forApplyOnly 로 만든 인스턴스 — 채널 구독 흐름 없음.
      return;
    }
    try {
      // 순서 주의 — race 회피를 위해 subscribe 를 먼저 활성화한다.
      //
      // 옛 순서 (fetchAll → flushOutbox → subscribe) 는 fetchAll snapshot 과 subscribe
      // 활성 시각 사이의 변경을 누락할 수 있다 (다른 client 가 그 사이 mutation 시).
      //
      // 새 순서:
      //   1) subscribe — 이후의 모든 변경은 _handle 로 수신
      //   2) fetchAll → applyInsertOrUpdate — snapshot 풀백. subscribe 후 받은 변경과
      //      중복돼도 LWW strict > 로 멱등 처리.
      //   3) flushOutbox — local 이 갖고 있던 미push mutation 을 원격으로.
      _channel = c
          .channel('solo_todo:todos:$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'solo_todo',
            table: 'todos',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: _handle,
          )
          .subscribe();

      // categories 채널 — todos 와 동일 패턴. updatedAt 없으므로 remote upsert 단순 적용.
      _categoriesChannel = c
          .channel('solo_todo:categories:$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'solo_todo',
            table: 'categories',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: _handleCategory,
          )
          .subscribe();

      // groups 채널.
      _groupsChannel = c
          .channel('solo_todo:groups:$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'solo_todo',
            table: 'groups',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: _handleGroup,
          )
          .subscribe();

      final remoteAll = await api.fetchAll(userId);
      for (final remote in remoteAll) {
        await applyInsertOrUpdate(remote);
      }

      // categories / groups snapshot 풀백 — 구독 후 받은 변경과 중복돼도 upsert 멱등.
      final remoteCategories = await categoriesApi.fetchAll(userId);
      for (final remote in remoteCategories) {
        await applyCategoryUpsert(remote);
      }
      final remoteGroups = await groupsApi.fetchAll(userId);
      for (final remote in remoteGroups) {
        await applyGroupUpsert(remote);
      }

      await flushOutbox();

      // 주기 retry — 일시 단절 후 자동 복구. 30 초마다 flush 시도 (큐 비어 있으면 no-op).
      _flushTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => flushOutbox(),
      );
    } catch (e) {
      debugPrint('[solo_todo] Supabase realtime 구독 실패: $e');
    }
  }

  /// 원격 변경을 local 에만 반영 (outbox 우회). LWW 로 stale payload 는 skip.
  ///
  /// public 인 이유 — _handle 의 분기를 단위 테스트로 직접 검증할 수 있게.
  @visibleForTesting
  Future<void> applyInsertOrUpdate(Todo remote) async {
    final local = await localApply.getById(remote.id);
    if (LastWriteWins.remoteWins(local, remote)) {
      await localApply.upsert(remote);
    }
  }

  @visibleForTesting
  Future<void> applyDelete(String id) async {
    await localApply.deleteById(id);
  }

  /// 원격 category 를 local 에만 반영 (outbox 우회). updatedAt 없으니 LWW 없이 단순 upsert.
  @visibleForTesting
  Future<void> applyCategoryUpsert(Category remote) async {
    await categoriesApply.upsert(remote);
  }

  @visibleForTesting
  Future<void> applyCategoryDelete(String id) async {
    await categoriesApply.deleteById(id);
  }

  /// 원격 group 을 local 에만 반영 (outbox 우회).
  @visibleForTesting
  Future<void> applyGroupUpsert(Group remote) async {
    await groupsApply.upsert(remote);
  }

  @visibleForTesting
  Future<void> applyGroupDelete(String id) async {
    await groupsApply.deleteById(id);
  }

  Future<void> _handleCategory(PostgresChangePayload payload) async {
    try {
      switch (payload.eventType) {
        case PostgresChangeEvent.insert:
        case PostgresChangeEvent.update:
          await applyCategoryUpsert(
            categoriesApi.categoryFromRow(payload.newRecord),
          );
          break;
        case PostgresChangeEvent.delete:
          final id = payload.oldRecord['id'] as String?;
          if (id != null) await applyCategoryDelete(id);
          break;
        case PostgresChangeEvent.all:
          break;
      }
    } catch (e) {
      debugPrint('[solo_todo] realtime category payload 처리 실패: $e');
    }
  }

  Future<void> _handleGroup(PostgresChangePayload payload) async {
    try {
      switch (payload.eventType) {
        case PostgresChangeEvent.insert:
        case PostgresChangeEvent.update:
          await applyGroupUpsert(groupsApi.groupFromRow(payload.newRecord));
          break;
        case PostgresChangeEvent.delete:
          final id = payload.oldRecord['id'] as String?;
          if (id != null) await applyGroupDelete(id);
          break;
        case PostgresChangeEvent.all:
          break;
      }
    } catch (e) {
      debugPrint('[solo_todo] realtime group payload 처리 실패: $e');
    }
  }

  Future<void> _handle(PostgresChangePayload payload) async {
    try {
      switch (payload.eventType) {
        case PostgresChangeEvent.insert:
        case PostgresChangeEvent.update:
          final remote = api.todoFromRow(payload.newRecord);
          await applyInsertOrUpdate(remote);
          break;
        case PostgresChangeEvent.delete:
          final id = payload.oldRecord['id'] as String?;
          if (id != null) await applyDelete(id);
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
    final c = client;
    if (c == null) return;
    for (final ch in [_channel, _categoriesChannel, _groupsChannel]) {
      if (ch == null) continue;
      try {
        await c.removeChannel(ch);
      } catch (_) {
        // 종료 단계 — 무시.
      }
    }
    _channel = null;
    _categoriesChannel = null;
    _groupsChannel = null;
  }
}

/// 인증된 user 가 있을 때만 [SupabaseRealtimeSync] 를 활성화하는 lifecycle provider.
///
/// 누군가 `ref.watch(supabaseRealtimeSyncProvider)` 호출해야 init 된다 (AppShell 이 watch).
///
/// 자기 self-receive 무한 루프 방지를 위해 [SupabaseRealtimeSync.localApply] 에는
/// **`LocalTodoRepository` 를 직접 주입** — outbox 우회. outbox flush 는 별도 콜백으로.
final supabaseRealtimeSyncProvider = Provider<SupabaseRealtimeSync?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final api = ref.watch(supabaseTodosApiProvider);
  final categoriesApi = ref.watch(supabaseCategoriesApiProvider);
  final groupsApi = ref.watch(supabaseGroupsApiProvider);
  final user = ref.watch(currentUserProvider);
  if (client == null ||
      api == null ||
      categoriesApi == null ||
      groupsApi == null ||
      user == null) {
    return null;
  }

  final db = ref.watch(appDatabaseProvider);
  final repo = ref.watch(todoRepositoryProvider);

  final sync = SupabaseRealtimeSync(
    client: client,
    api: api,
    localApply: LocalTodoRepository(db.todosDao),
    flushOutbox: () async {
      if (repo is SyncingTodoRepository) {
        await repo.flushPending();
      }
    },
    userId: user.id,
    categoriesApi: categoriesApi,
    // outbox 우회 — self-receive 무한 루프 방지. Syncing*Repository 금지.
    categoriesApply: LocalCategoriesRepository(db.categoriesDao),
    groupsApi: groupsApi,
    groupsApply: LocalGroupsRepository(db.groupsDao),
  );
  sync.start();
  ref.onDispose(sync.stop);
  return sync;
});
