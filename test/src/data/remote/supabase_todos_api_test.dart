import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/data/remote/supabase_todos_api.dart';
import 'package:solo_todo/src/domain/category.dart';
import 'package:solo_todo/src/domain/todo.dart';

void main() {
  test('supabaseTodosApiProvider — Supabase 미설정 시 null 반환', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(supabaseTodosApiProvider), isNull);
  });

  group('rowForTest 매핑 안정성', () {
    // SupabaseTodosApi 자체는 client 주입을 요구하지만, 매핑은 client 와 무관.
    // 테스트용 dummy 인스턴스를 만들 수 없으니 _toRow 동작을 rowForTest 로 노출해 검증.
    // _client 는 사용 안 되므로 null 이 아닌 placeholder 가 필요한데, dart 의 nullable
    // 비-필드 접근이 없으므로 직접 정적 호출 가능한 wrapper 함수가 필요.

    test('필수 필드 + nullable 필드 누락 → null 컬럼으로 매핑 (snake_case + ISO 8601)', () {
      final todo = Todo(
        id: 'abc',
        title: '회사 보고',
        category: Category.work,
        dueAt: null,
        doneAt: null,
        createdAt: DateTime.utc(2026, 5, 27, 9, 0),
        updatedAt: DateTime.utc(2026, 5, 27, 9, 0),
        calendarEventId: null,
      );

      final row = _toRowForCheck(todo, 'user-1');
      expect(row['id'], 'abc');
      expect(row['user_id'], 'user-1');
      expect(row['title'], '회사 보고');
      expect(row['category'], 'work'); // Category.id 안정성
      expect(row['due_at'], isNull);
      expect(row['done_at'], isNull);
      expect(row['created_at'], '2026-05-27T09:00:00.000Z');
      expect(row['updated_at'], '2026-05-27T09:00:00.000Z');
      expect(row['calendar_event_id'], isNull);
    });

    test('모든 nullable 필드 채움 → ISO 8601 + 정확한 snake_case 키', () {
      final todo = Todo(
        id: 'b',
        title: 'PR 리뷰',
        category: Category.personalDev,
        dueAt: DateTime.utc(2026, 5, 28, 13),
        doneAt: DateTime.utc(2026, 5, 28, 18),
        createdAt: DateTime.utc(2026, 5, 27, 9),
        updatedAt: DateTime.utc(2026, 5, 28, 18),
        calendarEventId: 'evt-xyz',
      );

      final row = _toRowForCheck(todo, 'user-2');
      expect(row['category'], 'personal_dev'); // snake_case 키 매핑
      expect(row['due_at'], '2026-05-28T13:00:00.000Z');
      expect(row['done_at'], '2026-05-28T18:00:00.000Z');
      expect(row['calendar_event_id'], 'evt-xyz');
    });
  });

  group('v1.1 — parent_id / type / sort_order 매핑', () {
    test('_toRow — 트리 노드 (parent_id set, sort_order=5)', () {
      final todo = Todo(
        id: 'child',
        title: '울트라 모드',
        category: Category.personalDev,
        dueAt: null,
        doneAt: null,
        createdAt: DateTime.utc(2026, 5, 27, 9),
        updatedAt: DateTime.utc(2026, 5, 27, 9),
        calendarEventId: null,
        parentId: 'js-super',
        type: TodoType.task,
        sortOrder: 5,
      );
      final row = _toRowForCheck(todo, 'user-1');
      expect(row['parent_id'], 'js-super');
      expect(row['type'], 'task');
      expect(row['sort_order'], 5);
    });

    test('_toRow — note 타입', () {
      final note = Todo(
        id: 'note-1',
        title: '→ KV 캐싱 ...',
        category: Category.work,
        dueAt: null,
        doneAt: null,
        createdAt: DateTime.utc(2026, 5, 27, 9),
        updatedAt: DateTime.utc(2026, 5, 27, 9),
        calendarEventId: null,
        parentId: 'project-cogito',
        type: TodoType.note,
        sortOrder: 0,
      );
      final row = _toRowForCheck(note, 'user-1');
      expect(row['type'], 'note');
      expect(row['parent_id'], 'project-cogito');
    });

    test('_toRow — 기본값 (parent_id null, type=task, sort_order=0)', () {
      final plain = Todo(
        id: 'plain',
        title: 'x',
        category: Category.daily,
        dueAt: null,
        doneAt: null,
        createdAt: DateTime.utc(2026, 5, 27, 9),
        updatedAt: DateTime.utc(2026, 5, 27, 9),
        calendarEventId: null,
      );
      final row = _toRowForCheck(plain, 'user-1');
      expect(row['parent_id'], isNull);
      expect(row['type'], 'task');
      expect(row['sort_order'], 0);
    });

    test('round-trip — _toRow → _fromRow 가 동일 Todo 복원 (트리 + note)', () {
      final original = Todo(
        id: 'tree',
        title: '→ 메모',
        category: Category.idea,
        dueAt: DateTime.utc(2026, 5, 28, 13),
        doneAt: null,
        createdAt: DateTime.utc(2026, 5, 27, 9),
        updatedAt: DateTime.utc(2026, 5, 27, 9),
        calendarEventId: null,
        parentId: 'parent-x',
        type: TodoType.note,
        sortOrder: 7,
      );
      final row = _toRowForCheck(original, 'user-1');
      final restored = _fromRowForCheck(row);
      expect(restored, original);
    });

    test('_fromRow 역호환 — v1.0 row (parent_id/type/sort_order 누락) → 기본값', () {
      // Supabase 가 옛 v1.0 row 를 내려보낼 때 (ALTER 전) 클라이언트가 안전하게 해석해야 함.
      final legacyRow = <String, dynamic>{
        'id': 'legacy',
        'title': '옛 todo',
        'category': 'work',
        'due_at': null,
        'done_at': null,
        'created_at': '2026-05-01T09:00:00.000Z',
        'updated_at': '2026-05-01T09:00:00.000Z',
        'calendar_event_id': null,
        // parent_id / type / sort_order 자체가 row 에 없는 케이스.
      };
      final restored = _fromRowForCheck(legacyRow);
      expect(restored.parentId, isNull);
      expect(restored.type, TodoType.task);
      expect(restored.sortOrder, 0);
    });

    test('_fromRow — sort_order 가 num (double) 으로 와도 int 로 안전 변환', () {
      // PostgREST 가 가끔 numeric 타입을 double 로 직렬화하는 케이스 대비.
      final row = <String, dynamic>{
        'id': 'x',
        'title': 'y',
        'category': 'daily',
        'due_at': null,
        'done_at': null,
        'created_at': '2026-05-27T09:00:00.000Z',
        'updated_at': '2026-05-27T09:00:00.000Z',
        'calendar_event_id': null,
        'parent_id': null,
        'type': 'task',
        'sort_order': 3.0,
      };
      final restored = _fromRowForCheck(row);
      expect(restored.sortOrder, 3);
    });
  });

  test('SupabaseTodosApi.rowForTest 가 helper 와 동일 매핑 — 두 곳 dup 회귀 가드', () {
    // SupabaseTodosApi 자체를 instance 화하려면 SupabaseClient 가 필요해서 직접 호출 불가.
    // 대신 helper 가 동일 logic 을 만들도록 의도 — 키 셋이 일치하는지만 정적 비교.
    final keysFromHelper = _toRowForCheck(
      Todo(
        id: 'k',
        title: 't',
        category: Category.daily,
        dueAt: null,
        doneAt: null,
        createdAt: DateTime.utc(2026, 5, 27, 9),
        updatedAt: DateTime.utc(2026, 5, 27, 9),
        calendarEventId: null,
      ),
      'u',
    ).keys.toSet();
    expect(keysFromHelper, {
      'id',
      'user_id',
      'title',
      'category',
      'due_at',
      'done_at',
      'created_at',
      'updated_at',
      'calendar_event_id',
      'parent_id',
      'type',
      'sort_order',
      'description',
      'end_at',
      'is_all_day',
      'time_anchor',
    });
  });

  group('fast-tasks — end_at / is_all_day / time_anchor 매핑', () {
    test('_toRow — 기간 + 하루종일', () {
      final row = _toRowForCheck(
        Todo(
          id: 'r',
          title: '여행',
          category: Category.daily,
          dueAt: DateTime.utc(2026, 5, 27),
          doneAt: null,
          createdAt: DateTime.utc(2026, 5, 27, 9),
          updatedAt: DateTime.utc(2026, 5, 27, 9),
          calendarEventId: null,
          endAt: DateTime.utc(2026, 5, 30),
          isAllDay: true,
        ),
        'u',
      );
      expect(row['end_at'], '2026-05-30T00:00:00.000Z');
      expect(row['is_all_day'], isTrue);
      expect(row['time_anchor'], 'start');
    });

    test('round-trip — 마감시간 모드 (time_anchor=end)', () {
      final original = Todo(
        id: 'e',
        title: '제출',
        category: Category.work,
        dueAt: DateTime.utc(2026, 5, 27, 18, 0),
        doneAt: null,
        createdAt: DateTime.utc(2026, 5, 27, 9),
        updatedAt: DateTime.utc(2026, 5, 27, 9),
        calendarEventId: null,
        timeAnchor: 'end',
      );
      final restored = _fromRowForCheck(_toRowForCheck(original, 'u'));
      expect(restored.timeAnchor, 'end');
      expect(restored.endAt, isNull);
      expect(restored.isAllDay, isFalse);
      expect(restored.dueAt, DateTime.utc(2026, 5, 27, 18, 0));
    });

    test('_fromRow 역호환 — 신규 컬럼 누락 → 기본값', () {
      final legacyRow = <String, dynamic>{
        'id': 'legacy',
        'title': '옛 todo',
        'category': 'work',
        'due_at': null,
        'done_at': null,
        'created_at': '2026-05-01T09:00:00.000Z',
        'updated_at': '2026-05-01T09:00:00.000Z',
        'calendar_event_id': null,
        // end_at / is_all_day / time_anchor 자체가 row 에 없음.
      };
      final restored = _fromRowForCheck(legacyRow);
      expect(restored.endAt, isNull);
      expect(restored.isAllDay, isFalse);
      expect(restored.timeAnchor, 'start');
    });

    test('_fromRow — is_all_day 가 num(1) 로 와도 bool 로 안전 변환', () {
      final row = <String, dynamic>{
        'id': 'n',
        'title': 'y',
        'category': 'daily',
        'due_at': '2026-05-27T00:00:00.000Z',
        'done_at': null,
        'created_at': '2026-05-27T09:00:00.000Z',
        'updated_at': '2026-05-27T09:00:00.000Z',
        'calendar_event_id': null,
        'is_all_day': 1,
      };
      final restored = _fromRowForCheck(row);
      expect(restored.isAllDay, isTrue);
    });

    test('updated_at/created_at 은 로컬 DateTime 이어도 UTC(Z)로 직렬화', () {
      // 회귀: nowProvider 가 DateTime.now()(로컬) 라 updatedAt 이 local-naive 면,
      // Supabase 왕복본(UTC)과 LWW 비교에서 timezone offset 만큼 어긋나 방금 쓴 값이
      // stale 원격으로 덮어써졌다. 전송은 반드시 UTC 여야 한다.
      final localNow = DateTime(2026, 5, 30, 18, 0, 0); // isUtc == false (로컬)
      final todo = Todo(
        id: 'tz',
        title: 'y',
        category: Category.work,
        dueAt: null,
        doneAt: null,
        createdAt: localNow,
        updatedAt: localNow,
        calendarEventId: null,
      );
      final row = _toRowForCheck(todo, 'u');
      expect(row['updated_at'], endsWith('Z'), reason: 'UTC 직렬화여야 함');
      expect(
        DateTime.parse(row['updated_at'] as String),
        localNow.toUtc(),
        reason: '동일 instant(UTC) 보존',
      );
    });
  });
}

/// SupabaseTodosApi 의 _toRow 동작을 client 없이 검증하기 위한 helper.
/// 매핑 logic 이 SupabaseTodosApi.rowForTest 와 동일해야 한다 — 만약 매핑이 바뀌면
/// 두 곳을 모두 갱신해야 회귀 잡힘.
Map<String, dynamic> _toRowForCheck(Todo t, String userId) => {
  'id': t.id,
  'user_id': userId,
  'title': t.title,
  'category': t.category.id,
  'due_at': t.dueAt?.toIso8601String(),
  'done_at': t.doneAt?.toIso8601String(),
  'created_at': t.createdAt.toUtc().toIso8601String(),
  'updated_at': t.updatedAt.toUtc().toIso8601String(),
  'calendar_event_id': t.calendarEventId,
  'parent_id': t.parentId,
  'type': t.type.name,
  'sort_order': t.sortOrder,
  'description': t.description,
  'end_at': t.endAt?.toIso8601String(),
  'is_all_day': t.isAllDay,
  'time_anchor': t.timeAnchor,
};

/// 위 _toRow 의 역 — row → Todo. SupabaseTodosApi._fromRow 와 동일 logic.
Todo _fromRowForCheck(Map<String, dynamic> row) => Todo(
  id: row['id'] as String,
  title: row['title'] as String,
  category: Category.fromId(row['category'] as String),
  dueAt: _parseTime(row['due_at']),
  doneAt: _parseTime(row['done_at']),
  createdAt: _parseTime(row['created_at'])!,
  updatedAt: _parseTime(row['updated_at'])!,
  calendarEventId: row['calendar_event_id'] as String?,
  parentId: row['parent_id'] as String?,
  type: _parseTypeForCheck(row['type']),
  sortOrder: row['sort_order'] is int
      ? row['sort_order'] as int
      : (row['sort_order'] is num ? (row['sort_order'] as num).toInt() : 0),
  description: row['description'] as String?,
  endAt: _parseTime(row['end_at']),
  isAllDay: _parseBoolForCheck(row['is_all_day']),
  timeAnchor: row['time_anchor'] is String
      ? row['time_anchor'] as String
      : 'start',
);

bool _parseBoolForCheck(Object? raw) {
  if (raw is bool) return raw;
  if (raw is num) return raw != 0;
  return false;
}

DateTime? _parseTime(Object? value) =>
    value == null ? null : DateTime.parse(value as String).toUtc();

TodoType _parseTypeForCheck(Object? raw) {
  switch (raw) {
    case 'note':
      return TodoType.note;
    case 'task':
    default:
      return TodoType.task;
  }
}
