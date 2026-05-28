import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';

import '../domain/category.dart';
import '../domain/todo.dart';
import 'local/app_database.dart';
import 'local/outbox_dao.dart';
import 'local/todos_dao.dart';
import 'remote/supabase_todos_api.dart';
import 'todo_repository.dart';

const _uuid = Uuid();

/// 로컬 [TodosDao] + 원격 [SupabaseTodosApi] 합성.
///
/// - mutation: local 먼저 → outbox enqueue → 즉시 push 시도. 실패 시 다음 flush 까지 대기.
/// - watch*: local 만 (원격 변경은 SupabaseRealtimeSync 가 local 에 반영).
/// - flushPending(): 큐에 쌓인 항목을 FIFO 순서로 push. 한 항목이라도 실패하면 break
///   (다음 retry 까지 순서 보존 — 동일 todo 의 후속 mutation 이 먼저 push 되는 것 방지).
class SyncingTodoRepository implements TodoRepository {
  SyncingTodoRepository({
    required this.local,
    required this.outbox,
    required this.api,
    required this.userIdGetter,
  });

  final TodosDao local;
  final OutboxDao outbox;
  final RemoteTodosApi api;

  /// 현재 인증된 user id. null 이면 원격 push skip (로컬 only).
  final String? Function() userIdGetter;

  // 동시 flush 방지 mutex. 진행 중에 새 mutation 이 들어와 [flushPending] 을 다시
  // 호출하면 _rerunRequested 만 set 하고 즉시 return. 첫 flush 가 끝난 후 한 번 더
  // 돌려 race 와 동시 호출 시 같은 outbox row 가 두 번 push 되는 것을 막는다.
  bool _flushing = false;
  bool _rerunRequested = false;

  // --- TodoRepository read API — local 위임 ----------------------------

  @override
  Future<Todo?> getById(String id) => local.getById(id);

  @override
  Stream<List<Todo>> watchAll() => local.watchAll();

  @override
  Stream<List<Todo>> watchByCategory(Category category) =>
      local.watchByCategory(category);

  @override
  Stream<List<Todo>> watchToday(DateTime Function() now) =>
      local.watchToday(now);

  // --- TodoRepository mutation API ------------------------------------

  @override
  Future<void> upsert(Todo todo) async {
    await local.upsert(todo);
    await outbox.enqueue(
      OutboxRow(
        id: _uuid.v4(),
        kind: 'upsert',
        todoId: todo.id,
        payload: jsonEncode(todo.toJson()),
        createdAt: DateTime.now().toUtc(),
      ),
    );
    unawaited(flushPending());
  }

  @override
  Future<void> deleteById(String id) async {
    await local.deleteById(id);
    await outbox.enqueue(
      OutboxRow(
        id: _uuid.v4(),
        kind: 'delete',
        todoId: id,
        payload: null,
        createdAt: DateTime.now().toUtc(),
      ),
    );
    unawaited(flushPending());
  }

  // --- 큐 처리 --------------------------------------------------------

  /// outbox 의 pending entry 를 FIFO 로 push. 실패 시 break.
  ///
  /// 동시 호출 시 race 방지 — 이미 진행 중이면 rerun 플래그만 set 하고 return. 진행 중인
  /// flush 가 종료된 직후 한 번 더 실행해 그동안 enqueue 된 entry 도 처리한다.
  Future<void> flushPending() async {
    if (_flushing) {
      _rerunRequested = true;
      return;
    }
    _flushing = true;
    try {
      do {
        _rerunRequested = false;
        await _doFlush();
      } while (_rerunRequested);
    } finally {
      _flushing = false;
    }
  }

  Future<void> _doFlush() async {
    final userId = userIdGetter();
    if (userId == null) return; // 미인증 — local only

    final entries = await outbox.allOrdered();
    for (final e in entries) {
      // categories kind ('cat-upsert' / 'cat-delete') 는 SyncingCategoriesRepository
      // 책임 — 같은 outbox 테이블을 공유하지만 서로 자기 kind 만 처리하고 다른 kind 는 skip.
      if (e.kind != 'upsert' && e.kind != 'delete') {
        continue;
      }
      try {
        if (e.kind == 'upsert') {
          final raw = e.payload;
          if (raw == null) {
            await outbox.removeById(e.id);
            continue;
          }
          final todo = Todo.fromJson(jsonDecode(raw) as Map<String, dynamic>);
          await api.upsert(todo, userId);
        } else if (e.kind == 'delete') {
          await api.deleteById(e.todoId, userId);
        }
        await outbox.removeById(e.id);
      } catch (err) {
        debugPrint('[solo_todo] outbox flush 중단 (재시도 대기): $err');
        break; // 순서 보존 — 다음 retry 때 같은 entry 부터 재시도.
      }
    }
  }
}
