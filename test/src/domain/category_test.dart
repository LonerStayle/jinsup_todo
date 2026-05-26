import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/domain/category.dart';

void main() {
  group('Category', () {
    test('정확히 5개 카테고리 (work / personalDev / daily / longterm / idea)', () {
      expect(Category.values.length, 5);
      expect(Category.values, [
        Category.work,
        Category.personalDev,
        Category.daily,
        Category.longterm,
        Category.idea,
      ]);
    });

    test('모든 id 가 유일하고 snake_case 임', () {
      final ids = Category.values.map((c) => c.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'id 중복 없음');
      for (final id in ids) {
        expect(
          RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(id),
          isTrue,
          reason: 'id "$id" 가 snake_case 가 아닙니다.',
        );
      }
    });

    test('모든 한글 label 이 유일하고 비어있지 않다', () {
      final labels = Category.values.map((c) => c.label).toList();
      expect(labels.toSet().length, labels.length);
      for (final label in labels) {
        expect(label, isNotEmpty);
      }
    });

    test('shortcutDigit 가 1~5 로 카테고리 순서대로 매핑된다', () {
      for (var i = 0; i < Category.values.length; i++) {
        expect(Category.values[i].shortcutDigit, i + 1);
      }
    });

    test('fromId / tryFromId round-trip', () {
      for (final c in Category.values) {
        expect(Category.fromId(c.id), c);
        expect(Category.tryFromId(c.id), c);
      }
    });

    test('fromId 미지 키 → ArgumentError, tryFromId 미지 키 → null', () {
      expect(() => Category.fromId('ghost'), throwsArgumentError);
      expect(Category.tryFromId('ghost'), isNull);
    });

    test('id 안정성 (스키마/DB 호환을 위해 고정해서 추적)', () {
      // 향후 enum 이름이 바뀌어도 이 매핑은 깨지면 안 된다.
      expect(Category.work.id, 'work');
      expect(Category.personalDev.id, 'personal_dev');
      expect(Category.daily.id, 'daily');
      expect(Category.longterm.id, 'longterm');
      expect(Category.idea.id, 'idea');
    });
  });
}
