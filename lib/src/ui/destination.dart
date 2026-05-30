import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../domain/category.dart';

/// destination 의 종류 — UI 라우팅 분기에 사용.
enum DestinationKind { today, category, outline }

/// 사이드바 / 바텀 네비의 단일 navigation 단위.
///
/// 순서 (v1.4 / Task G — 전체보기를 '오늘' 바로 아래로):
/// - `today` (kind=today) 가 항상 첫 번째 — 단축키 0.
/// - `outline` (kind=outline) 이 두 번째 — 단축키 1. ('오늘' 다음으로 자주 본다)
/// - 그 다음 categories (DB row 순서 = sortOrder asc) — 단축키 2~9 (앞 8개만).
///
/// v1.0~v1.1 의 `AppDestination.all` (static) 은 v1.2 부터 [buildAll] 로 동적 생성.
/// 호환을 위해 `all` 도 [Category.builtinSeeds] 기준으로 노출 (테스트 / 옛 호출처용).
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

  /// `0` = Today, `1` = Outline, `2~9` = categories (앞 8개).
  /// 음수 = 단축키 없음 (카테고리가 9개 이상일 때 후순위 destination 들).
  final int shortcutDigit;

  /// kind == category 일 때만 non-null. 그 외엔 null.
  final Category? category;

  bool get isToday => kind == DestinationKind.today;
  bool get isOutline => kind == DestinationKind.outline;

  /// 단축키가 있으면 "회사 할일 (1)", 없으면 그냥 "회사 할일".
  String get tooltipWithShortcut =>
      shortcutDigit < 0 ? label : '$label ($shortcutDigit)';

  /// v1.4 (Task G) — categories 를 받아 동적 destination 리스트 생성.
  ///
  /// 순서·단축키: today (digit 0) → outline (digit 1) → categories (digit 2~9, 앞 8개).
  /// 9번째 이후 카테고리는 단축키 없음 (sidebar / NavigationBar tap 으로만 접근).
  static List<AppDestination> buildAll(List<Category> categories) {
    final dests = <AppDestination>[
      const AppDestination._(
        kind: DestinationKind.today,
        label: '오늘',
        icon: Icons.today_outlined,
        color: AppPalette.accent,
        shortcutDigit: 0,
      ),
      // v1.4 — 전체보기를 '오늘' 바로 다음으로. 단축키 1.
      const AppDestination._(
        kind: DestinationKind.outline,
        label: '전체보기',
        icon: Icons.account_tree_outlined,
        color: AppPalette.accent,
        shortcutDigit: 1,
      ),
    ];

    for (var i = 0; i < categories.length; i++) {
      final c = categories[i];
      // 앞 8개만 단축키 2~9 부여 — 9번째 이후는 단축키 없음.
      final digit = i < 8 ? i + 2 : -1;
      dests.add(
        AppDestination._(
          kind: DestinationKind.category,
          label: c.label,
          icon: c.icon,
          color: c.color,
          category: c,
          shortcutDigit: digit,
        ),
      );
    }

    return dests;
  }

  /// builtin 5종 기준의 default destination 리스트 — 옛 호출처 / 테스트 호환.
  /// v1.2 production 코드는 [buildAll] + `categoriesProvider` 를 사용해야 동적.
  static final List<AppDestination> all = buildAll(Category.builtinSeeds);
}
