import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/category.dart';
import '../../domain/todo.dart';
import 'supabase_provider.dart';

/// Supabase `todos` 테이블 CRUD wrapper.
///
/// 로컬 Drift 는 camelCase (dueAt) 컬럼명을 그대로 쓰지만, Supabase 측은 SQL
/// 컨벤션상 snake_case (due_at). 매핑은 이 클래스가 단일 출처로 관리.
///
/// RLS 정책 (SETUP.html 에 SQL 포함):
///   - SELECT/INSERT/UPDATE/DELETE: `auth.uid() = user_id`
class SupabaseTodosApi {
  SupabaseTodosApi(this._client);

  static const _table = 'todos';

  final SupabaseClient _client;

  /// id 기준 upsert. updatedAt 은 호출자가 미리 갱신한 상태여야 한다
  /// ([TodoRepository] 계약과 동일 — last-write-wins).
  Future<void> upsert(Todo todo, String userId) async {
    await _client.from(_table).upsert(_toRow(todo, userId));
  }

  Future<void> deleteById(String id, String userId) async {
    await _client.from(_table).delete().eq('id', id).eq('user_id', userId);
  }

  /// 초기 풀백 — 로그인 직후 또는 재연결 시 호출.
  Future<List<Todo>> fetchAll(String userId) async {
    final rows = await _client.from(_table).select().eq('user_id', userId);
    return rows.map((r) => _fromRow(r)).toList();
  }

  // ---- 매핑 헬퍼 ---------------------------------------------------------

  Map<String, dynamic> _toRow(Todo t, String userId) => {
    'id': t.id,
    'user_id': userId,
    'title': t.title,
    'category': t.category.id,
    'due_at': t.dueAt?.toIso8601String(),
    'done_at': t.doneAt?.toIso8601String(),
    'created_at': t.createdAt.toIso8601String(),
    'updated_at': t.updatedAt.toIso8601String(),
    'calendar_event_id': t.calendarEventId,
  };

  Todo _fromRow(Map<String, dynamic> row) => Todo(
    id: row['id'] as String,
    title: row['title'] as String,
    category: Category.fromId(row['category'] as String),
    dueAt: _parseTime(row['due_at']),
    doneAt: _parseTime(row['done_at']),
    createdAt: _parseTime(row['created_at'])!,
    updatedAt: _parseTime(row['updated_at'])!,
    calendarEventId: row['calendar_event_id'] as String?,
  );

  /// PostgREST 는 timestamptz 를 ISO 8601 문자열로 반환.
  DateTime? _parseTime(Object? value) =>
      value == null ? null : DateTime.parse(value as String).toUtc();

  /// [Todo] → DB row 직접 노출 (테스트/매핑 안정성 검증용).
  Map<String, dynamic> rowForTest(Todo t, String userId) => _toRow(t, userId);

  /// realtime payload (newRecord) → 도메인 [Todo] 변환. SupabaseRealtimeSync 가 사용.
  Todo todoFromRow(Map<String, dynamic> row) => _fromRow(row);
}

final supabaseTodosApiProvider = Provider<SupabaseTodosApi?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : SupabaseTodosApi(client);
});
