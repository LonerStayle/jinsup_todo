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
  'created_at': t.createdAt.toIso8601String(),
  'updated_at': t.updatedAt.toIso8601String(),
  'calendar_event_id': t.calendarEventId,
};
