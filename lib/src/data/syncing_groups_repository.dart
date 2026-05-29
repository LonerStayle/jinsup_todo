import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';

import '../domain/group.dart';
import 'groups_repository.dart';
import 'local/app_database.dart';
import 'local/groups_dao.dart';
import 'local/outbox_dao.dart';
import 'remote/supabase_groups_api.dart';

const _uuid = Uuid();

/// outbox kind 식별자 — todos 의 'upsert'/'delete', categories 의 'cat-*' 와 구분.
const String _kindUpsert = 'grp-upsert';
const String _kindDelete = 'grp-delete';

/// categories 의 upsert kind — 그룹 삭제 시 detach 된 카테고리를 remote 에 반영하기 위해
/// 같은 outbox 에 enqueue. (SyncingCategoriesRepository 의 'cat-upsert' 와 동일 문자열.)
const String _kindCatUpsert = 'cat-upsert';

/// 로컬 [GroupsDao] + 원격 [RemoteGroupsApi] 합성. [SyncingCategoriesRepository] 미러.
///
/// - mutation: local 먼저 → outbox enqueue → 즉시 push 시도. 실패 시 다음 flush 대기.
/// - watchAll / getAll / getById: local 만.
/// - flushPending(): 같은 outbox 테이블을 todos / categories / groups 가 공유.
///   자기 kind (grp-*) 가 아닌 entry 는 skip 하고 grp-* 만 FIFO 처리. (단, 그룹
///   삭제 시 enqueue 한 cat-upsert 는 SyncingCategoriesRepository 가 처리한다.)
class SyncingGroupsRepository implements GroupsRepository {
  SyncingGroupsRepository({
    required this.local,
    required this.outbox,
    required this.api,
    required this.userIdGetter,
  });

  final GroupsDao local;
  final OutboxDao outbox;
  final RemoteGroupsApi api;
  final String? Function() userIdGetter;

  bool _flushing = false;
  bool _rerunRequested = false;

  // --- read API — local 위임 -----------------------------------------

  @override
  Future<Group?> getById(String id) => local.getById(id);

  @override
  Future<List<Group>> getAll() => local.getAll();

  @override
  Stream<List<Group>> watchAll() => local.watchAll();

  // --- mutation API --------------------------------------------------

  @override
  Future<void> upsert(Group group) async {
    await local.upsert(group);
    await outbox.enqueue(
      OutboxRow(
        id: _uuid.v4(),
        kind: _kindUpsert,
        todoId: group.id,
        payload: jsonEncode(group.toJson()),
        createdAt: DateTime.now().toUtc(),
      ),
    );
    unawaited(flushPending());
  }

  @override
  Future<int> deleteById(String id) async {
    // 1) 삭제될 그룹에 속한 카테고리 — 미분류 이동 후 값(groupId=null) 으로 받아온다.
    final detached = await local.categoriesInGroup(id);
    // 2) local 에서 detach (groupId=null) 후 그룹 row 삭제.
    await local.detachCategories(id);
    final affected = await local.deleteById(id);
    // 3) remote 반영: detach 된 카테고리들의 group_id=null 을 cat-upsert 로 push.
    for (final c in detached) {
      await outbox.enqueue(
        OutboxRow(
          id: _uuid.v4(),
          kind: _kindCatUpsert,
          todoId: c.id,
          payload: jsonEncode(c.toJson()),
          createdAt: DateTime.now().toUtc(),
        ),
      );
    }
    // 4) 그룹 삭제 자체.
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

  /// SyncingCategoriesRepository.flushPending 과 동일한 mutex 패턴.
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
      // grp-* 만 이 repository 책임. todos / cat-* 는 각자 repository 가 flush.
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
          final g = Group.fromJson(jsonDecode(raw) as Map<String, dynamic>);
          await api.upsert(g, userId);
        } else if (e.kind == _kindDelete) {
          await api.deleteById(e.todoId, userId);
        }
        await outbox.removeById(e.id);
      } catch (err) {
        debugPrint('[solo_todo] groups outbox flush 중단 (재시도 대기): $err');
        break;
      }
    }
  }
}
