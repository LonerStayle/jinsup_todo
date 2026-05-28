import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';

import '../domain/category.dart';
import 'categories_repository.dart';
import 'local/app_database.dart';
import 'local/categories_dao.dart';
import 'local/outbox_dao.dart';
import 'remote/supabase_categories_api.dart';

const _uuid = Uuid();

/// outbox kind 식별자 — todos 의 'upsert' / 'delete' 와 구분.
const String _kindUpsert = 'cat-upsert';
const String _kindDelete = 'cat-delete';

/// 로컬 [CategoriesDao] + 원격 [RemoteCategoriesApi] 합성.
///
/// SyncingTodoRepository 패턴 답습:
/// - mutation: local 먼저 → outbox enqueue → 즉시 push 시도. 실패 시 다음 flush 대기.
/// - watchAll / getAll / countTodosOfCategory: local 만 (원격 변경은 Realtime sync 가
///   local 에 반영).
/// - flushPending(): 같은 outbox 테이블을 todos / categories 가 공유한다. 자기 kind
///   가 아닌 entry 는 skip 하고 자기 kind 만 FIFO 로 처리. 자기 kind 안에서 실패 시
///   break (순서 보존).
class SyncingCategoriesRepository implements CategoriesRepository {
  SyncingCategoriesRepository({
    required this.local,
    required this.outbox,
    required this.api,
    required this.userIdGetter,
  });

  final CategoriesDao local;
  final OutboxDao outbox;
  final RemoteCategoriesApi api;
  final String? Function() userIdGetter;

  bool _flushing = false;
  bool _rerunRequested = false;

  // --- read API — local 위임 -----------------------------------------

  @override
  Future<Category?> getById(String id) => local.getById(id);

  @override
  Future<List<Category>> getAll() => local.getAll();

  @override
  Stream<List<Category>> watchAll() => local.watchAll();

  @override
  Future<int> countTodosOfCategory(String id) => local.countTodosOfCategory(id);

  // --- mutation API --------------------------------------------------

  @override
  Future<void> upsert(Category category) async {
    await local.upsert(category);
    await outbox.enqueue(
      OutboxRow(
        id: _uuid.v4(),
        kind: _kindUpsert,
        todoId: category.id,
        payload: jsonEncode(category.toJson()),
        createdAt: DateTime.now().toUtc(),
      ),
    );
    unawaited(flushPending());
  }

  @override
  Future<int> deleteById(String id) async {
    final affected = await local.deleteById(id);
    await outbox.enqueue(
      OutboxRow(
        id: _uuid.v4(),
        kind: _kindDelete,
        todoId: id,
        payload: null,
        createdAt: DateTime.now().toUtc(),
      ),
    );
    unawaited(flushPending());
    return affected;
  }

  // --- 큐 처리 -------------------------------------------------------

  /// SyncingTodoRepository.flushPending 과 동일한 mutex 패턴.
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
    if (userId == null) return;

    final entries = await outbox.allOrdered();
    for (final e in entries) {
      // todos kind 는 SyncingTodoRepository 책임.
      if (e.kind != _kindUpsert && e.kind != _kindDelete) {
        continue;
      }
      try {
        if (e.kind == _kindUpsert) {
          final raw = e.payload;
          if (raw == null) {
            await outbox.removeById(e.id);
            continue;
          }
          final c = Category.fromJson(jsonDecode(raw) as Map<String, dynamic>);
          await api.upsert(c, userId);
        } else if (e.kind == _kindDelete) {
          await api.deleteById(e.todoId, userId);
        }
        await outbox.removeById(e.id);
      } catch (err) {
        debugPrint('[solo_todo] categories outbox flush 중단 (재시도 대기): $err');
        break;
      }
    }
  }
}
