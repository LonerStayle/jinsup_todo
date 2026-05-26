import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local/app_database.dart';
import 'local/local_todo_repository.dart';
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

/// [TodoRepository] 의 기본 구현 (local only). phase 7 에서 SyncingTodoRepository 로 교체.
final todoRepositoryProvider = Provider<TodoRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return LocalTodoRepository(db.todosDao);
});

/// 현재 시각을 주입 가능하게 — 테스트에서 결정성 보장 + 자정 트리거 갱신 대응.
final nowProvider = Provider<DateTime Function()>((ref) => DateTime.now);
