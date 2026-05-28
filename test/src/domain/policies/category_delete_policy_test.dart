import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/domain/category.dart';
import 'package:solo_todo/src/domain/policies/category_delete_policy.dart';

void main() {
  group('CategoryDeletePolicy.canDelete', () {
    test('todoCount = 0 → DeleteCheck.ok', () {
      final result = CategoryDeletePolicy.canDelete(Category.work, 0);
      expect(result, const DeleteCheck.ok());
      expect(result.isOk, isTrue);
    });

    test('todoCount = 1 → DeleteCheck.blockedByTodos(1)', () {
      final result = CategoryDeletePolicy.canDelete(Category.daily, 1);
      expect(result, const DeleteCheck.blockedByTodos(1));
      expect(result.isOk, isFalse);
    });

    test('todoCount = 5 → DeleteCheck.blockedByTodos(5)', () {
      final result = CategoryDeletePolicy.canDelete(Category.idea, 5);
      expect(result, const DeleteCheck.blockedByTodos(5));
      expect(result.isOk, isFalse);
    });

    test('builtin / 사용자 정의 구분 없이 동일한 정책', () {
      // builtin (Category.work, isBuiltin=true) — count 0 → ok.
      expect(CategoryDeletePolicy.canDelete(Category.work, 0).isOk, isTrue);

      // 사용자 정의 (isBuiltin=false) — count 0 → ok, 동일.
      const custom = Category(
        id: 'study',
        label: '공부',
        iconCodePoint: 0xe865,
        colorValue: 0xFF888888,
        sortOrder: 99,
        isBuiltin: false,
      );
      expect(CategoryDeletePolicy.canDelete(custom, 0).isOk, isTrue);
      expect(
        CategoryDeletePolicy.canDelete(custom, 3),
        const DeleteCheck.blockedByTodos(3),
      );
    });
  });

  group('DeleteCheck', () {
    test('blockedByTodos 의 count 가 동일하면 == 이 true', () {
      expect(
        const DeleteCheck.blockedByTodos(2),
        const DeleteCheck.blockedByTodos(2),
      );
      expect(
        const DeleteCheck.blockedByTodos(2),
        isNot(const DeleteCheck.blockedByTodos(3)),
      );
      expect(
        const DeleteCheck.blockedByTodos(2),
        isNot(const DeleteCheck.ok()),
      );
    });
  });
}
