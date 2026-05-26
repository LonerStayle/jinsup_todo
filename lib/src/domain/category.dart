import 'package:flutter/material.dart';

/// Solo Todo 의 카테고리 5종. CLAUDE.md 의 비전에 고정.
///
/// 각 값은 DB 저장용 [id], 한글 [label], 시각화용 [color] + [icon] 를 갖는다.
/// 색은 phase 4 디자인 토큰 task 에서 본격 검증 (WCAG AA 대비 등) 후 보강될 수 있다.
enum Category {
  work(
    id: 'work',
    label: '회사 할일',
    color: Color(0xFF2A66FF),
    icon: Icons.business_center_outlined,
  ),
  personalDev(
    id: 'personal_dev',
    label: '개인개발',
    color: Color(0xFF8B5CF6),
    icon: Icons.code,
  ),
  daily(
    id: 'daily',
    label: '일상',
    color: Color(0xFF10B981),
    icon: Icons.home_outlined,
  ),
  longterm(
    id: 'longterm',
    label: '장기 목표',
    color: Color(0xFFEF4444),
    icon: Icons.flag_outlined,
  ),
  idea(
    id: 'idea',
    label: '아이디어',
    color: Color(0xFFF59E0B),
    icon: Icons.lightbulb_outline,
  );

  const Category({
    required this.id,
    required this.label,
    required this.color,
    required this.icon,
  });

  /// DB / JSON 직렬화에 쓰는 안정 키. enum 이름이 변경되어도 [id] 는 보존해야 한다.
  final String id;

  /// 사용자에게 보여주는 한글 라벨.
  final String label;

  /// 카테고리 컬러바 / 아이콘 배경에 쓰는 시그니처 색상.
  final Color color;

  /// 카테고리 시각화에 쓰는 아이콘 (Material Icons — macOS / Android 공용).
  final IconData icon;

  /// 키보드 단축 (`1`~`5`) 으로 카테고리 전환할 때 쓰는 위치 (1-based).
  int get shortcutDigit => Category.values.indexOf(this) + 1;

  /// 저장된 [id] 로부터 카테고리를 복원. 미지 id 는 [ArgumentError].
  static Category fromId(String id) {
    return Category.values.firstWhere(
      (c) => c.id == id,
      orElse: () => throw ArgumentError('Unknown category id: $id'),
    );
  }

  /// [Category.fromId] 의 safe 버전. 미지 id 면 null 반환.
  static Category? tryFromId(String id) {
    for (final c in Category.values) {
      if (c.id == id) return c;
    }
    return null;
  }
}
