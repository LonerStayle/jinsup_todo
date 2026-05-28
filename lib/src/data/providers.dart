import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/auth_providers.dart';
import 'local/app_database.dart';
import 'local/local_todo_repository.dart';
import 'remote/supabase_todos_api.dart';
import 'syncing_todo_repository.dart';
import 'todo_repository.dart';

/// 앱 전역에서 단일 인스턴스로 유지되는 SQLite [AppDatabase].
///
/// 테스트에서는 `appDatabaseProvider.overrideWithValue(AppDatabase.memory())` 로
/// in-memory 인스턴스로 교체한다.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// [TodoRepository] — Supabase enabled + 인증된 user 가 있으면 [SyncingTodoRepository]
/// (local + outbox + remote push), 아니면 [LocalTodoRepository] (local only).
final todoRepositoryProvider = Provider<TodoRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final api = ref.watch(supabaseTodosApiProvider);

  if (api == null) {
    return LocalTodoRepository(db.todosDao);
  }
  return SyncingTodoRepository(
    local: db.todosDao,
    outbox: db.outboxDao,
    api: api,
    // userIdGetter 가 호출 시점마다 ref.read 로 현재 user 반환 — sign-in/out 동적 추적.
    userIdGetter: () => ref.read(currentUserProvider)?.id,
  );
});

/// 현재 시각을 주입 가능하게 — 테스트에서 결정성 보장 + 자정 트리거 갱신 대응.
final nowProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// outbox 의 pending entry 수 stream. UI 의 "동기화 대기 N건" indicator 가 watch.
/// count == 0 이면 모두 push 완료 (또는 미인증 → 큐 비어 있음).
final outboxCountProvider = StreamProvider<int>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.outboxDao.watchCount();
});
