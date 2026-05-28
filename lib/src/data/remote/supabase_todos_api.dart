import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/category.dart';
import '../../domain/todo.dart';
import 'supabase_provider.dart';

/// 원격 todos 저장소 계약. Supabase 외 다른 백엔드 / fake 가 동일 인터페이스 구현 가능.
abstract interface class RemoteTodosApi {
  Future<void> upsert(Todo todo, String userId);
  Future<void> deleteById(String id, String userId);
  Future<List<Todo>> fetchAll(String userId);
  Todo todoFromRow(Map<String, dynamic> row);
}

/// Supabase `todos` 테이블 CRUD wrapper.
///
/// 로컬 Drift 는 camelCase (dueAt) 컬럼명을 그대로 쓰지만, Supabase 측은 SQL
/// 컨벤션상 snake_case (due_at). 매핑은 이 클래스가 단일 출처로 관리.
///
/// RLS 정책 (SETUP.html 에 SQL 포함):
///   - SELECT/INSERT/UPDATE/DELETE: `auth.uid() = user_id`
class SupabaseTodosApi implements RemoteTodosApi {
  SupabaseTodosApi(this._client);

  /// 무료 플랜 1 프로젝트를 다른 앱과 공유할 때 격리. Supabase Dashboard 의
  /// Settings → API → Exposed Schemas 에 [_schema] 가 추가돼 있어야 PostgREST 가 인식.
  static const _schema = 'solo_todo';
  static const _table = 'todos';

  final SupabaseClient _client;

  /// schema-bound query builder. supabase_flutter 의 `schema()` 는 새 wrapper 반환이라
  /// 호출 시점마다 만들지 않고 lazy field 로 캐싱.
  late final _qb = _client.schema(_schema);

  /// id 기준 upsert. updatedAt 은 호출자가 미리 갱신한 상태여야 한다
  /// ([TodoRepository] 계약과 동일 — last-write-wins).
  @override
  Future<void> upsert(Todo todo, String userId) async {
    await _qb.from(_table).upsert(_toRow(todo, userId));
  }

  @override
  Future<void> deleteById(String id, String userId) async {
    await _qb.from(_table).delete().eq('id', id).eq('user_id', userId);
  }

  /// 초기 풀백 — 로그인 직후 또는 재연결 시 호출.
  @override
  Future<List<Todo>> fetchAll(String userId) async {
    final rows = await _qb.from(_table).select().eq('user_id', userId);
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
    // v1.1 — 트리 / 메모 모델
    'parent_id': t.parentId,
    'type': t.type.name,
    'sort_order': t.sortOrder,
    // v1.2 — 상세 메모
    'description': t.description,
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
    // v1.1 — 옛 v1.0 row (컬럼 없음) 도 안전하게 기본값으로 복원.
    parentId: row['parent_id'] as String?,
    type: _parseType(row['type']),
    sortOrder: row['sort_order'] is int
        ? row['sort_order'] as int
        : (row['sort_order'] is num ? (row['sort_order'] as num).toInt() : 0),
    // v1.2 — 옛 v1.1 row 는 description 컬럼이 없어 null fallback.
    description: row['description'] as String?,
  );

  /// 미지의 type 문자열 또는 누락 시 'task' 로 안전 fallback (TodosDao._parseType 와 일관).
  static TodoType _parseType(Object? raw) {
    switch (raw) {
      case 'note':
        return TodoType.note;
      case 'task':
      default:
        return TodoType.task;
    }
  }

  /// PostgREST 는 timestamptz 를 ISO 8601 문자열로 반환.
  DateTime? _parseTime(Object? value) =>
      value == null ? null : DateTime.parse(value as String).toUtc();

  /// [Todo] → DB row 직접 노출 (테스트/매핑 안정성 검증용).
  Map<String, dynamic> rowForTest(Todo t, String userId) => _toRow(t, userId);

  /// realtime payload (newRecord) → 도메인 [Todo] 변환. SupabaseRealtimeSync 가 사용.
  @override
  Todo todoFromRow(Map<String, dynamic> row) => _fromRow(row);
}

final supabaseTodosApiProvider = Provider<SupabaseTodosApi?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : SupabaseTodosApi(client);
});
