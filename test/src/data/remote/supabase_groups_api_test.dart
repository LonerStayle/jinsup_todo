import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:solo_todo/src/data/remote/supabase_groups_api.dart';
import 'package:solo_todo/src/domain/group.dart';

/// SupabaseGroupsApi 의 매핑 / round-trip 검증. SupabaseCategoriesApi 패턴 미러.
void main() {
  late SupabaseGroupsApi api;

  setUp(() {
    final client = SupabaseClient('https://example.supabase.co', 'anon');
    api = SupabaseGroupsApi(client);
  });

  group('SupabaseGroupsApi — _toRow', () {
    test('Group → snake_case row', () {
      const g = Group(
        id: 'grp-a',
        label: '회사',
        colorValue: 0xFF2A66FF,
        sortOrder: 100,
      );
      final row = api.rowForTest(g, 'user-uuid-123');
      expect(row['id'], 'grp-a');
      expect(row['user_id'], 'user-uuid-123');
      expect(row['label'], '회사');
      expect(row['color_value'], 0xFF2A66FF);
      expect(row['sort_order'], 100);
      expect(row['is_builtin'], false);
    });
  });

  group('SupabaseGroupsApi — _fromRow / groupFromRow', () {
    test('정상 row → Group 복원', () {
      final row = <String, dynamic>{
        'id': 'grp-a',
        'user_id': 'u',
        'label': '회사',
        'color_value': 0xFF2A66FF,
        'sort_order': 100,
        'is_builtin': false,
      };
      final g = api.groupFromRow(row);
      expect(g.id, 'grp-a');
      expect(g.label, '회사');
      expect(g.colorValue, 0xFF2A66FF);
      expect(g.sortOrder, 100);
      expect(g.isBuiltin, isFalse);
    });

    test('PostgREST num → int 변환 (color_value / sort_order)', () {
      final row = <String, dynamic>{
        'id': 'grp-b',
        'user_id': 'u',
        'label': '사이드',
        'color_value': 0xFF22C55E as num,
        'sort_order': 100 as num,
        'is_builtin': false,
      };
      final g = api.groupFromRow(row);
      expect(g.colorValue, 0xFF22C55E);
      expect(g.sortOrder, 100);
    });

    test('is_builtin null → false 기본', () {
      final row = <String, dynamic>{
        'id': 'grp-c',
        'user_id': 'u',
        'label': '기타',
        'color_value': 0xFF6B7280,
        'sort_order': 0,
        'is_builtin': null,
      };
      expect(api.groupFromRow(row).isBuiltin, isFalse);
    });

    test('round-trip — _toRow 결과를 _fromRow 로 복원 시 동일 Group', () {
      const g = Group(
        id: 'grp-a',
        label: '회사',
        colorValue: 0xFF2A66FF,
        sortOrder: 100,
      );
      final restored = api.groupFromRow(api.rowForTest(g, 'u'));
      expect(restored, g);
    });
  });
}
