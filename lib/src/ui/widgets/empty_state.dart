import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// "할 일 없음" 류의 빈 상태 일관 위젯. 모든 화면이 같은 시각 언어를 쓰도록 강제한다
/// (디자인 점수 § 일관성).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.tone,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// null 이면 [ColorScheme.primary] 사용. 카테고리 색 등 의미 강조용으로 주입 가능.
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = tone ?? theme.colorScheme.primary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppTokens.radiusL),
              ),
              child: Icon(icon, size: 36, color: color),
            ),
            const SizedBox(height: AppTokens.space20),
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppTokens.space8),
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
