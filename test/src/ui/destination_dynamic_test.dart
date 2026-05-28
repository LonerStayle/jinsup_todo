import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/domain/category.dart';
import 'package:solo_todo/src/ui/destination.dart';

/// v1.2 — AppDestination.buildAll 동적 단축키 매핑 검증.
///
/// today=0 / categories 1~min(9,N) / outline N+1 (N<9) 또는 단축키 없음.
void main() {
  group('AppDestination.buildAll', () {
    test('빈 categories — today + outline 만 (outline digit 1)', () {
      final dests = AppDestination.buildAll(const []);
      expect(dests.length, 2);
      expect(dests[0].isToday, isTrue);
      expect(dests[0].shortcutDigit, 0);
      expect(dests[1].isOutline, isTrue);
      expect(dests[1].shortcutDigit, 1);
    });

    test('builtin 5종 — today=0 / 1~5 카테고리 / outline=6', () {
      final dests = AppDestination.buildAll(Category.builtinSeeds);
      expect(dests.length, 7);
      expect(dests[0].shortcutDigit, 0); // today
      for (var i = 0; i < 5; i++) {
        expect(dests[i + 1].shortcutDigit, i + 1);
        expect(dests[i + 1].category, Category.builtinSeeds[i]);
      }
      expect(dests.last.shortcutDigit, 6);
      expect(dests.last.isOutline, isTrue);
    });

    test('8 카테고리 — 1~8 + outline=9', () {
      final eight = [
        for (var i = 0; i < 8; i++)
          Category(
            id: 'c$i',
            label: 'C$i',
            iconCodePoint: 0xe865,
            colorValue: 0xFF000000,
            sortOrder: i,
            isBuiltin: false,
          ),
      ];
      final dests = AppDestination.buildAll(eight);
      expect(dests.length, 10);
      for (var i = 0; i < 8; i++) {
        expect(dests[i + 1].shortcutDigit, i + 1);
      }
      expect(dests.last.shortcutDigit, 9); // outline
    });

    test('9 카테고리 — 1~9 + outline 단축키 없음 (-1)', () {
      final nine = [
        for (var i = 0; i < 9; i++)
          Category(
            id: 'c$i',
            label: 'C$i',
            iconCodePoint: 0xe865,
            colorValue: 0xFF000000,
            sortOrder: i,
            isBuiltin: false,
          ),
      ];
      final dests = AppDestination.buildAll(nine);
      expect(dests.length, 11);
      // 9 categories: 1~9
      for (var i = 0; i < 9; i++) {
        expect(dests[i + 1].shortcutDigit, i + 1);
      }
      // outline 은 단축키 없음.
      expect(dests.last.shortcutDigit, -1);
    });

    test('12 카테고리 — 처음 9개만 단축키 / 10~12 + outline 단축키 없음', () {
      final twelve = [
        for (var i = 0; i < 12; i++)
          Category(
            id: 'c$i',
            label: 'C$i',
            iconCodePoint: 0xe865,
            colorValue: 0xFF000000,
            sortOrder: i,
            isBuiltin: false,
          ),
      ];
      final dests = AppDestination.buildAll(twelve);
      expect(dests.length, 14); // today + 12 cat + outline
      // 1~9 카테고리 — 단축키 1~9
      for (var i = 0; i < 9; i++) {
        expect(dests[i + 1].shortcutDigit, i + 1);
      }
      // 10~12 카테고리 — 단축키 없음
      for (var i = 9; i < 12; i++) {
        expect(dests[i + 1].shortcutDigit, -1);
      }
      // outline 단축키도 없음.
      expect(dests.last.shortcutDigit, -1);
    });

    test('tooltipWithShortcut — 단축키 -1 이면 라벨만', () {
      final dests = AppDestination.buildAll([
        Category(
          id: 'c',
          label: '커스텀',
          iconCodePoint: 0xe865,
          colorValue: 0xFF000000,
          sortOrder: 0,
          isBuiltin: false,
        ),
      ]);
      expect(dests[1].tooltipWithShortcut, '커스텀 (1)');

      // 10+ 카테고리에선 후순위 destination 의 tooltip 은 라벨만.
      final many = [
        for (var i = 0; i < 11; i++)
          Category(
            id: 'c$i',
            label: 'C$i',
            iconCodePoint: 0xe865,
            colorValue: 0xFF000000,
            sortOrder: i,
            isBuiltin: false,
          ),
      ];
      final manyDests = AppDestination.buildAll(many);
      expect(manyDests[10].tooltipWithShortcut, 'C9'); // 10번째 카테고리 — 단축키 없음
      expect(manyDests.last.tooltipWithShortcut, '전체보기'); // outline 도 단축키 없음
    });
  });
}
