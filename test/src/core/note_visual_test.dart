import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solo_todo/src/core/theme.dart';
import 'package:solo_todo/src/domain/category.dart';

/// §13-1 — note 전용 시각 토큰([NoteVisual]) 단위 검증.
/// 라이트/다크 alpha 분기 + 카테고리 5색 반영을 보장한다.
void main() {
  group('NoteVisual 상수', () {
    test('accent 보더 두께 3px / 라벨 문구 "메모"', () {
      expect(NoteVisual.accentWidth, 3.0);
      expect(NoteVisual.label, '메모');
    });

    test('틴트 alpha 는 다크가 라이트보다 진하다', () {
      expect(NoteVisual.tintAlphaDark, greaterThan(NoteVisual.tintAlphaLight));
    });
  });

  group('NoteVisual.tint — 라이트/다크 분기', () {
    test('라이트는 0.08, 다크는 0.16 alpha', () {
      final light = NoteVisual.tint(Category.work, Brightness.light);
      final dark = NoteVisual.tint(Category.work, Brightness.dark);
      expect(light.a, closeTo(NoteVisual.tintAlphaLight, 0.001));
      expect(dark.a, closeTo(NoteVisual.tintAlphaDark, 0.001));
    });

    test('틴트는 카테고리색 RGB 를 보존한다 (alpha 만 다름)', () {
      final c = Category.idea.color;
      final tint = NoteVisual.tint(Category.idea, Brightness.light);
      expect(tint.r, closeTo(c.r, 0.001));
      expect(tint.g, closeTo(c.g, 0.001));
      expect(tint.b, closeTo(c.b, 0.001));
    });
  });

  group('NoteVisual.accent / label 색', () {
    test('accent 는 카테고리색 원색', () {
      expect(NoteVisual.accent(Category.daily), Category.daily.color);
    });

    test('라벨 전경은 원색, 배경/외곽선은 저알파', () {
      final cat = Category.personalDev;
      expect(NoteVisual.labelForeground(cat), cat.color);
      expect(
        NoteVisual.labelBackground(cat).a,
        closeTo(NoteVisual.labelBgAlpha, 0.001),
      );
      expect(
        NoteVisual.labelOutline(cat).a,
        closeTo(NoteVisual.labelOutlineAlpha, 0.001),
      );
    });
  });

  group('카테고리 5색 반영', () {
    test('builtin 5종 각각 accent/틴트가 자기 색을 따른다', () {
      expect(Category.builtinSeeds.length, 5);
      for (final cat in Category.builtinSeeds) {
        // accent = 원색
        expect(NoteVisual.accent(cat), cat.color);
        // 틴트 = 같은 RGB, 라이트 alpha
        final tint = NoteVisual.tint(cat, Brightness.light);
        expect(tint.r, closeTo(cat.color.r, 0.001));
        expect(tint.g, closeTo(cat.color.g, 0.001));
        expect(tint.b, closeTo(cat.color.b, 0.001));
        expect(tint.a, closeTo(NoteVisual.tintAlphaLight, 0.001));
      }
    });
  });
}
