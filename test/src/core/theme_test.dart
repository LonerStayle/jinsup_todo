import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macos_ui/macos_ui.dart';

import 'package:solo_todo/src/core/theme.dart';

void main() {
  group('AppTokens', () {
    test('spacing 토큰이 모두 4 의 배수 (또는 2)', () {
      // 4 의 배수 그리드 — space2 는 hairline 보조용 예외.
      const fours = [
        AppTokens.space4,
        AppTokens.space8,
        AppTokens.space12,
        AppTokens.space16,
        AppTokens.space20,
        AppTokens.space24,
        AppTokens.space32,
        AppTokens.space40,
        AppTokens.space48,
      ];
      for (final s in fours) {
        expect(s % 4, 0, reason: '$s 가 4 의 배수가 아닙니다 (디자인 그리드 위반).');
      }
    });

    test('radius 토큰이 단조 증가', () {
      expect(AppTokens.radiusS, lessThan(AppTokens.radiusM));
      expect(AppTokens.radiusM, lessThan(AppTokens.radiusL));
    });

    test('motion duration 이 단조 증가', () {
      expect(AppTokens.motionFast, lessThan(AppTokens.motionMid));
      expect(AppTokens.motionMid, lessThan(AppTokens.motionSlow));
    });
  });

  group('AppTheme.mobile*', () {
    test('mobileLight() 가 Material 3 + brightness=light + accent primary', () {
      final t = AppTheme.mobileLight();
      expect(t.useMaterial3, isTrue);
      expect(t.brightness, Brightness.light);
      expect(t.colorScheme.primary, AppPalette.accent);
      expect(t.scaffoldBackgroundColor, AppPalette.lightBg);
      expect(t.textTheme.titleMedium?.fontSize, 17);
    });

    test('mobileDark() 가 Material 3 + brightness=dark', () {
      final t = AppTheme.mobileDark();
      expect(t.useMaterial3, isTrue);
      expect(t.brightness, Brightness.dark);
      expect(t.colorScheme.primary, AppPalette.accent);
      expect(t.scaffoldBackgroundColor, AppPalette.darkBg);
    });
  });

  group('AppTheme.desktop*', () {
    test('desktopLight() 가 MacosThemeData (light) + accent primary', () {
      final t = AppTheme.desktopLight();
      expect(t, isA<MacosThemeData>());
      expect(t.primaryColor, AppPalette.accent);
    });

    test('desktopDark() 가 MacosThemeData (dark) + accent primary', () {
      final t = AppTheme.desktopDark();
      expect(t, isA<MacosThemeData>());
      expect(t.primaryColor, AppPalette.accent);
    });
  });
}
