import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:solo_todo/src/data/remote/supabase_categories_api.dart';
import 'package:solo_todo/src/domain/category.dart';

/// SupabaseCategoriesApi 의 매핑 / round-trip 검증.
///
/// `rowForTest` 가 `_toRow` 의 결과를 노출하므로 네트워크 호출 없이도 매핑 일관성
/// 검증 가능 (SupabaseTodosApi 패턴과 동일). `_fromRow` 는 `categoryFromRow` 로
/// public 노출 (realtime payload 와 동일 entry point).
void main() {
  // 더미 SupabaseClient — _toRow / _fromRow 만 검증하므로 lazy schema() 도 호출 안 됨.
  late SupabaseCategoriesApi api;

  setUp(() {
    final client = SupabaseClient('https://example.supabase.co', 'anon');
    api = SupabaseCategoriesApi(client);
  });

  group('SupabaseCategoriesApi — _toRow', () {
    test('builtin Category.work → snake_case row', () {
      final row = api.rowForTest(Category.work, 'user-uuid-123');
      expect(row['id'], 'work');
      expect(row['user_id'], 'user-uuid-123');
      expect(row['label'], '회사 할일');
      expect(row['icon_code_point'], 0xef0a);
      expect(row['color_value'], 0xFF2A66FF);
      expect(row['sort_order'], 0);
      expect(row['is_builtin'], true);
    });

    test('사용자 정의 Category — isBuiltin=false + 임의 sortOrder', () {
      const custom = Category(
        id: 'study',
        label: '공부',
        iconCodePoint: 0xe865,
        colorValue: 0xFF888888,
        sortOrder: 99,
        isBuiltin: false,
      );
      final row = api.rowForTest(custom, 'u');
      expect(row['id'], 'study');
      expect(row['label'], '공부');
      expect(row['icon_code_point'], 0xe865);
      expect(row['sort_order'], 99);
      expect(row['is_builtin'], false);
    });
  });

  group('SupabaseCategoriesApi — _fromRow / categoryFromRow', () {
    test('정상 row → Category 복원', () {
      final row = <String, dynamic>{
        'id': 'personal_dev',
        'user_id': 'u',
        'label': '개인개발',
        'icon_code_point': 0xe176,
        'color_value': 0xFF8B5CF6,
        'sort_order': 1,
        'is_builtin': true,
      };
      final c = api.categoryFromRow(row);
      expect(c.id, 'personal_dev');
      expect(c.label, '개인개발');
      expect(c.iconCodePoint, 0xe176);
      expect(c.colorValue, 0xFF8B5CF6);
      expect(c.sortOrder, 1);
      expect(c.isBuiltin, isTrue);
    });

    test('PostgREST num → int 변환 (sort_order / icon_code_point)', () {
      final row = <String, dynamic>{
        'id': 'study',
        'user_id': 'u',
        'label': '공부',
        // PostgREST 가 정수를 num 으로 반환할 수 있음.
        'icon_code_point': 0xe865 as num,
        'color_value': 0xFF888888 as num,
        'sort_order': 99 as num,
        'is_builtin': false,
      };
      final c = api.categoryFromRow(row);
      expect(c.iconCodePoint, 0xe865);
      expect(c.colorValue, 0xFF888888);
      expect(c.sortOrder, 99);
    });

    test('is_builtin null → false 기본', () {
      final row = <String, dynamic>{
        'id': 'idea',
        'user_id': 'u',
        'label': '아이디어',
        'icon_code_point': 0xe37c,
        'color_value': 0xFFF59E0B,
        'sort_order': 4,
        'is_builtin': null,
      };
      final c = api.categoryFromRow(row);
      expect(c.isBuiltin, isFalse);
    });

    test('round-trip — _toRow 결과를 _fromRow 로 복원 시 동일 Category', () {
      const custom = Category(
        id: 'study',
        label: '공부',
        iconCodePoint: 0xe865,
        colorValue: 0xFF888888,
        sortOrder: 99,
        isBuiltin: false,
      );
      final row = api.rowForTest(custom, 'u');
      final restored = api.categoryFromRow(row);
      expect(restored, custom);
    });

    test('round-trip — builtin 5종 모두 안정적', () {
      for (final c in Category.builtinSeeds) {
        final row = api.rowForTest(c, 'u');
        final restored = api.categoryFromRow(row);
        expect(restored, c, reason: 'builtin ${c.id} round-trip 안정성');
      }
    });
  });
}
