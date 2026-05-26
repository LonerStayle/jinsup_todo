import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';

/// 디자인 토큰 + 라이트/다크 [ThemeData] · [MacosThemeData] 생성기.
///
/// 본격 토큰 (간격 / 타이포 / 컬러 팔레트) 은 phase 4 UI 골격 task 에서 채운다.
/// 지금은 다른 모듈이 import 만 할 수 있도록 최소 placeholder 만 둔다.
class AppTheme {
  const AppTheme._();

  // 간격 그리드 (4 / 8 / 16 / 24)
  static const double spaceXs = 4;
  static const double spaceS = 8;
  static const double spaceM = 16;
  static const double spaceL = 24;

  // 라운드 코너
  static const double radiusS = 8;
  static const double radiusM = 12;

  static const Color _seed = Color(0xFF2A66FF);

  // --- mobile (Material) ---------------------------------------------------

  static ThemeData mobileLight() => ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: _seed),
    useMaterial3: true,
  );

  static ThemeData mobileDark() => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
  );

  // --- desktop (macos_ui) --------------------------------------------------

  static MacosThemeData desktopLight() => MacosThemeData.light();

  static MacosThemeData desktopDark() => MacosThemeData.dark();
}
