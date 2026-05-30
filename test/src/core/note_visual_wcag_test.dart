import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solo_todo/src/core/theme.dart';
import 'package:solo_todo/src/domain/category.dart';

/// §13-10 — note 타일의 텍스트 대비가 라이트/다크 양쪽에서 WCAG AA(본문 4.5:1)를
/// 만족하는지 카테고리 5색 전부에 대해 계산 검증한다.
///
/// 검증 대상 텍스트 3종:
/// - 제목(onSurface) on 틴트 배경
/// - 본문 프리뷰(onSurfaceMuted) on 틴트 배경
/// - "메모" 라벨(labelForeground=onSurface) on 라벨칩 배경
///
/// accent 좌측 보더(카테고리 원색)는 1.4.11 비텍스트 요소지만 메모 식별이 글리프/
/// 라벨/틴트로 이미 중복 전달되므로 단독 지표가 아니다 → 텍스트 대비만 게이트한다.
void main() {
  // sRGB 채널 → 선형값.
  double lin(double c) =>
      c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

  // WCAG 상대 휘도.
  double luminance(Color c) =>
      0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);

  // 대비비 (≥1).
  double ratio(Color a, Color b) {
    final la = luminance(a);
    final lb = luminance(b);
    final hi = math.max(la, lb);
    final lo = math.min(la, lb);
    return (hi + 0.05) / (lo + 0.05);
  }

  // 반투명 fg 를 불투명 base 위에 합성한 실제 색.
  Color over(Color fg, Color base) {
    final a = fg.a;
    return Color.from(
      alpha: 1,
      red: fg.r * a + base.r * (1 - a),
      green: fg.g * a + base.g * (1 - a),
      blue: fg.b * a + base.b * (1 - a),
    );
  }

  void checkMode(Brightness b) {
    final base = b == Brightness.dark ? AppPalette.darkBg : AppPalette.lightBg;
    final onSurface = b == Brightness.dark
        ? AppPalette.darkOnSurface
        : AppPalette.lightOnSurface;
    final muted = b == Brightness.dark
        ? AppPalette.darkOnSurfaceMuted
        : AppPalette.lightOnSurfaceMuted;
    final labelFg = NoteVisual.labelForeground(b);

    for (final cat in Category.builtinSeeds) {
      // 틴트 배경 = tint 를 scaffold base 위에 합성. 헤딩은 더 진한 틴트.
      final tintBg = over(NoteVisual.tint(cat, b), base);
      final headingBg = over(NoteVisual.headingTint(cat, b), base);
      // 라벨 배경 = labelBackground 를 틴트 배경 위에 합성.
      final labelBg = over(NoteVisual.labelBackground(cat), tintBg);

      // leaf 틴트 + 헤딩 틴트 양쪽에서 제목/프리뷰 텍스트 대비 검증.
      for (final bg in [tintBg, headingBg]) {
        expect(
          ratio(onSurface, bg),
          greaterThanOrEqualTo(4.5),
          reason: '제목 대비 부족: ${cat.id} / $b',
        );
        expect(
          ratio(muted, bg),
          greaterThanOrEqualTo(4.5),
          reason: '프리뷰 대비 부족: ${cat.id} / $b',
        );
      }
      expect(
        ratio(labelFg, labelBg),
        greaterThanOrEqualTo(4.5),
        reason: '"메모" 라벨 대비 부족: ${cat.id} / $b',
      );
    }
  }

  test('WCAG AA — 라이트 모드 5색 텍스트 대비 ≥ 4.5:1', () {
    checkMode(Brightness.light);
  });

  test('WCAG AA — 다크 모드 5색 텍스트 대비 ≥ 4.5:1', () {
    checkMode(Brightness.dark);
  });

  test('대비 헬퍼 sanity — 흑/백 = 21:1, 동색 = 1:1', () {
    expect(
      ratio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
      closeTo(21.0, 0.1),
    );
    expect(
      ratio(const Color(0xFF123456), const Color(0xFF123456)),
      closeTo(1.0, 0.001),
    );
  });
}
