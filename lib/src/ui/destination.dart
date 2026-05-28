import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../domain/category.dart';

/// destination 의 종류 — UI 라우팅 분기에 사용.
enum DestinationKind { today, category, outline }

/// 사이드바 / 바텀 네비의 단일 navigation 단위.
///
/// `today` (kind=today) 는 항상 첫 번째. 그 뒤로 [Category.values] 5 개,
/// 마지막에 outline (kind=outline). 총 7 개의 destination. shortcutDigit 은
/// 0~6 단축키 (AppShell 의 ShortcutsHost).
class AppDestination {
  const AppDestination._({
    required this.kind,
    required this.label,
    required this.icon,
    required this.color,
    required this.shortcutDigit,
    this.category,
  });

  final DestinationKind kind;
  final String label;
  final IconData icon;
  final Color color;

  /// 0 = Today, 1~5 = Category.values 순서, 6 = Outline.
  final int shortcutDigit;

  /// kind == category 일 때만 non-null. 그 외엔 null.
  final Category? category;

  bool get isToday => kind == DestinationKind.today;
  bool get isOutline => kind == DestinationKind.outline;

  /// Tooltip 으로 보여줄 단축키 안내. "회사 할일 (1)" 같은 형태.
  String get tooltipWithShortcut => '$label ($shortcutDigit)';

  static final List<AppDestination> all = [
    const AppDestination._(
      kind: DestinationKind.today,
      label: '오늘',
      icon: Icons.today_outlined,
      color: AppPalette.accent,
      shortcutDigit: 0,
    ),
    for (var i = 0; i < Category.values.length; i++)
      AppDestination._(
        kind: DestinationKind.category,
        label: Category.values[i].label,
        icon: Category.values[i].icon,
        color: Category.values[i].color,
        category: Category.values[i],
        shortcutDigit: i + 1,
      ),
    const AppDestination._(
      kind: DestinationKind.outline,
      label: '전체보기',
      icon: Icons.account_tree_outlined,
      color: AppPalette.accent,
      shortcutDigit: 6,
    ),
  ];
}
