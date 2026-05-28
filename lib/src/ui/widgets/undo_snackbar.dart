import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// 삭제/이동 같은 reversible action 후 호출. floating SnackBar + "되돌리기" 액션.
///
/// - 자동 dismiss 후에는 onUndo 호출되지 않음. 사용자가 액션 누르면 즉시 dismiss + onUndo 호출.
/// - 호출자는 이전 SnackBar 가 떠 있을 가능성을 고려해 [hideCurrentBeforeShow] 로 즉시 교체 가능.
/// - content 영역에 [duration] 과 같은 길이의 progress bar 가 표시되어 "남은 undo 시간"
///   을 시각적으로 알려준다 (1.0 → 0.0 감소).
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showUndoSnackbar(
  BuildContext context, {
  required String message,
  required VoidCallback onUndo,
  Duration duration = const Duration(seconds: 5),
  bool hideCurrentBeforeShow = true,
}) {
  final messenger = ScaffoldMessenger.of(context);
  if (hideCurrentBeforeShow) messenger.hideCurrentSnackBar();

  return messenger.showSnackBar(
    SnackBar(
      content: _UndoContent(message: message, duration: duration),
      behavior: SnackBarBehavior.floating,
      duration: duration,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusM),
      ),
      action: SnackBarAction(label: '되돌리기', onPressed: onUndo),
    ),
  );
}

class _UndoContent extends StatelessWidget {
  const _UndoContent({required this.message, required this.duration});

  final String message;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(message),
        const SizedBox(height: AppTokens.space8),
        // SnackBar content 의 onSurfaceVariant 색 위에 시각 대비를 확보 — 진행 trace 는
        // 반투명, 진행 bar 자체는 onInverseSurface (SnackBar 의 텍스트 톤과 어울리는 색).
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTokens.radiusFull),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 1.0, end: 0.0),
            duration: duration,
            // 사용자가 직관적으로 "시간이 줄어든다" 를 느끼게 linear.
            curve: Curves.linear,
            builder: (_, value, _) => LinearProgressIndicator(
              key: const ValueKey('undo-snackbar-progress'),
              value: value,
              minHeight: 3,
              backgroundColor: theme.colorScheme.onInverseSurface.withValues(
                alpha: 0.22,
              ),
              color: theme.colorScheme.onInverseSurface,
            ),
          ),
        ),
      ],
    );
  }
}
