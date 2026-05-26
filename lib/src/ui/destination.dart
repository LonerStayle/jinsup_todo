import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../domain/category.dart';

/// 사이드바 / 바텀 네비의 단일 navigation 단위.
///
/// `today` (null category) 는 항상 첫 번째. 그 뒤로 [Category.values] 순서대로
/// 5 개. 총 6 개의 destination.
class AppDestination {
  const AppDestination._({
    required this.label,
    required this.icon,
    required this.color,
    this.category,
  });

  final String label;
  final IconData icon;
  final Color color;

  /// null 이면 "오늘" 화면. 값이 있으면 해당 카테고리 필터 화면.
  final Category? category;

  bool get isToday => category == null;

  static final List<AppDestination> all = [
    const AppDestination._(
      label: '오늘',
      icon: Icons.today_outlined,
      color: AppPalette.accent,
    ),
    ...Category.values.map(
      (c) => AppDestination._(
        label: c.label,
        icon: c.icon,
        color: c.color,
        category: c,
      ),
    ),
  ];
}
