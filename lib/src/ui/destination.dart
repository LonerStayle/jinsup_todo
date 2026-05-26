import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../domain/category.dart';

/// 사이드바 / 바텀 네비의 단일 navigation 단위.
///
/// `today` (null category) 는 항상 첫 번째. 그 뒤로 [Category.values] 순서대로
/// 5 개. 총 6 개의 destination. shortcutDigit 은 0~5 단축키 (AppShell 의 ShortcutsHost).
class AppDestination {
  const AppDestination._({
    required this.label,
    required this.icon,
    required this.color,
    required this.shortcutDigit,
    this.category,
  });

  final String label;
  final IconData icon;
  final Color color;

  /// 0 = Today, 1~5 = Category.values 순서.
  final int shortcutDigit;

  /// null 이면 "오늘" 화면. 값이 있으면 해당 카테고리 필터 화면.
  final Category? category;

  bool get isToday => category == null;

  /// Tooltip 으로 보여줄 단축키 안내. "회사 할일 (1)" 같은 형태.
  String get tooltipWithShortcut => '$label ($shortcutDigit)';

  static final List<AppDestination> all = [
    const AppDestination._(
      label: '오늘',
      icon: Icons.today_outlined,
      color: AppPalette.accent,
      shortcutDigit: 0,
    ),
    for (var i = 0; i < Category.values.length; i++)
      AppDestination._(
        label: Category.values[i].label,
        icon: Category.values[i].icon,
        color: Category.values[i].color,
        category: Category.values[i],
        shortcutDigit: i + 1,
      ),
  ];
}
