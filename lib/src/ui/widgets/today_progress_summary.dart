import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// 오늘 화면 상단 진척 요약 카드 — 원형 진행 링 + "오늘 N/M 완료" 텍스트.
///
/// [total] 은 오늘 task(메모 제외) 수, [done] 은 그중 완료 수. total 이 0 이면
/// (오늘 task 가 없음) 호출 쪽에서 아예 렌더하지 않는 게 권장이지만, 안전망으로
/// 0 일 때는 빈 위젯을 반환한다.
class TodayProgressSummary extends StatelessWidget {
  const TodayProgressSummary({
    super.key,
    required this.done,
    required this.total,
  });

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    if (total <= 0) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isComplete = done >= total;
    final remaining = total - done;
    final ratio = total == 0 ? 0.0 : done / total;

    // 완료 시 성공 그린(= daily 카테고리 hue), 진행 중엔 accent 블루.
    const successColor = Color(0xFF10B981);
    final ringColor = isComplete ? successColor : scheme.primary;

    return Container(
      key: const ValueKey('today-progress-summary'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space16,
        vertical: AppTokens.space16,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusL),
        border: Border.all(
          color: ringColor.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.35 : 0.22,
          ),
          width: AppTokens.hairline,
        ),
      ),
      child: Row(
        children: [
          _ProgressRing(
            ratio: ratio,
            color: ringColor,
            track: scheme.outline,
            isComplete: isComplete,
            done: done,
            total: total,
            labelStyle: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: AppTokens.space16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isComplete ? '오늘 할 일 모두 끝냈어요' : '오늘 $done / $total 완료',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isComplete ? successColor : scheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppTokens.space2),
                Text(
                  isComplete ? '깔끔하게 비웠어요. 잘하셨어요 🎉' : '$remaining개 남았어요',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          // 우측 큰 퍼센트 — 한눈 가시성 보강.
          Text(
            '${(ratio * 100).round()}%',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: ringColor,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({
    required this.ratio,
    required this.color,
    required this.track,
    required this.isComplete,
    required this.done,
    required this.total,
    required this.labelStyle,
  });

  final double ratio;
  final Color color;
  final Color track;
  final bool isComplete;
  final int done;
  final int total;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    const size = 52.0;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(ratio: ratio, color: color, track: track),
        child: Center(
          child: isComplete
              ? Icon(Icons.check_rounded, size: 24, color: color)
              : Text('$done/$total', style: labelStyle),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.ratio, required this.color, required this.track});

  final double ratio;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 6.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track.withValues(alpha: 0.5)
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    final sweep = (ratio.clamp(0.0, 1.0)) * 2 * math.pi;
    if (sweep <= 0) return;
    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = color
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.ratio != ratio || old.color != color || old.track != track;
}
