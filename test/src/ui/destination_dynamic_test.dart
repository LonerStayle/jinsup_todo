import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/domain/category.dart';
import 'package:solo_todo/src/ui/destination.dart';

/// v1.4 (Task G) — AppDestination.buildAll 동적 단축키 매핑 검증.
///
/// 순서·단축키: today=0 / outline=1 / categories 2~9 (앞 8개) / 9번째부터 단축키 없음.
void main() {
  group('AppDestination.buildAll', () {
    test('빈 categories — today + outline 만 (today=0, outline=1)', () {
      final dests = AppDestination.buildAll(const []);
      expect(dests.length, 2);
      expect(dests[0].isToday, isTrue);
      expect(dests[0].shortcutDigit, 0);
      expect(dests[1].isOutline, isTrue);
      expect(dests[1].shortcutDigit, 1);
    });

    test('builtin 5종 — today=0 / outline=1 / 카테고리 2~6', () {
      final dests = AppDestination.buildAll(Category.builtinSeeds);
      expect(dests.length, 7);
      // 순서: today, outline, 그 다음 카테고리.
      expect(dests[0].isToday, isTrue);
      expect(dests[0].shortcutDigit, 0);
      expect(dests[1].isOutline, isTrue);
      expect(dests[1].shortcutDigit, 1);
      for (var i = 0; i < 5; i++) {
        expect(dests[i + 2].shortcutDigit, i + 2);
        expect(dests[i + 2].category, Category.builtinSeeds[i]);
      }
    });

    test('8 카테고리 — 카테고리 2~9 (앞 8개 모두 단축키)', () {
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
      expect(dests[0].shortcutDigit, 0); // today
      expect(dests[1].shortcutDigit, 1); // outline
      for (var i = 0; i < 8; i++) {
        expect(dests[i + 2].shortcutDigit, i + 2); // 2~9
      }
    });

    test('9 카테고리 — 앞 8개만 2~9, 9번째는 단축키 없음 (-1)', () {
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
      expect(dests[1].shortcutDigit, 1); // outline
      // 앞 8개 카테고리 — 2~9
      for (var i = 0; i < 8; i++) {
        expect(dests[i + 2].shortcutDigit, i + 2);
      }
      // 9번째 카테고리 — 단축키 없음.
      expect(dests.last.shortcutDigit, -1);
    });

    test('12 카테고리 — 앞 8개만 단축키 2~9 / 나머지 -1', () {
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
      expect(dests.length, 14); // today + outline + 12 cat
      expect(dests[1].shortcutDigit, 1); // outline
      // 앞 8개 카테고리 — 단축키 2~9
      for (var i = 0; i < 8; i++) {
        expect(dests[i + 2].shortcutDigit, i + 2);
      }
      // 9~12번째 카테고리 — 단축키 없음
      for (var i = 8; i < 12; i++) {
        expect(dests[i + 2].shortcutDigit, -1);
      }
    });

    test('tooltipWithShortcut — 단축키 있으면 (n), 없으면 라벨만', () {
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
      // today, outline, 커스텀(digit 2).
      expect(dests[1].tooltipWithShortcut, '전체보기 (1)');
      expect(dests[2].tooltipWithShortcut, '커스텀 (2)');

      // 9개 이상 카테고리에선 후순위 destination 의 tooltip 은 라벨만.
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
      // index 2..9 (앞 8개) 단축키 있음, index 10 (9번째 카테고리) 부터 없음.
      expect(manyDests[10].tooltipWithShortcut, 'C8'); // 9번째 카테고리 — 단축키 없음
      expect(manyDests.last.tooltipWithShortcut, 'C10'); // 마지막 카테고리 — 단축키 없음
    });
  });
}
