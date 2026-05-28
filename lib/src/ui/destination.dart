import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../domain/category.dart';

/// destination 의 종류 — UI 라우팅 분기에 사용.
enum DestinationKind { today, category, outline }

/// 사이드바 / 바텀 네비의 단일 navigation 단위.
///
/// 순서:
/// - `today` (kind=today) 가 항상 첫 번째 — 단축키 0.
/// - 그 다음 categories (DB row 순서 = sortOrder asc) — 단축키 1~9 (앞 9개만).
/// - 마지막 outline (kind=outline) — 카테고리가 8개 이하면 N+1 단축키, 9 이상이면 단축키 없음.
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

  /// `0` = Today, `1~9` = categories (앞 9개), `N+1` = Outline (단, N<9).
  /// 음수 = 단축키 없음 (카테고리가 ≥9 개일 때 후순위 destination 들).
  final int shortcutDigit;

  /// kind == category 일 때만 non-null. 그 외엔 null.
  final Category? category;

  bool get isToday => kind == DestinationKind.today;
  bool get isOutline => kind == DestinationKind.outline;

  /// 단축키가 있으면 "회사 할일 (1)", 없으면 그냥 "회사 할일".
  String get tooltipWithShortcut =>
      shortcutDigit < 0 ? label : '$label ($shortcutDigit)';

  /// v1.2 — categories 를 받아 동적 destination 리스트 생성.
  ///
  /// today (digit 0) → categories (digit 1~min(9,N)) → outline (digit N+1 if N<9
  /// else 없음). 9 개 초과 카테고리는 sidebar / NavigationBar tap 으로만 접근.
  static List<AppDestination> buildAll(List<Category> categories) {
    final dests = <AppDestination>[
      const AppDestination._(
        kind: DestinationKind.today,
        label: '오늘',
        icon: Icons.today_outlined,
        color: AppPalette.accent,
        shortcutDigit: 0,
      ),
    ];

    for (var i = 0; i < categories.length; i++) {
      final c = categories[i];
      dests.add(
        AppDestination._(
          kind: DestinationKind.category,
          label: c.label,
          icon: c.icon,
          color: c.color,
          category: c,
          // 앞 9개만 단축키 1~9 부여 — N>9 면 후순위는 단축키 없음.
          shortcutDigit: i < 9 ? i + 1 : -1,
        ),
      );
    }

    // outline 단축키 — 카테고리 8개 이하면 N+1 (=2~9), 9 이상이면 단축키 풀이 모두
    // 카테고리에 할당돼 outline 은 sidebar / tap 전용.
    final outlineDigit = categories.length < 9 ? categories.length + 1 : -1;
    dests.add(
      AppDestination._(
        kind: DestinationKind.outline,
        label: '전체보기',
        icon: Icons.account_tree_outlined,
        color: AppPalette.accent,
        shortcutDigit: outlineDigit,
      ),
    );

    return dests;
  }

  /// builtin 5종 기준의 default destination 리스트 — 옛 호출처 / 테스트 호환.
  /// v1.2 production 코드는 [buildAll] + `categoriesProvider` 를 사용해야 동적.
  static final List<AppDestination> all = buildAll(Category.builtinSeeds);
}
