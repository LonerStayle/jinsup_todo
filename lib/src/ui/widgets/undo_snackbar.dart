import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// 삭제/이동 같은 reversible action 후 호출. floating SnackBar + "되돌리기" 액션.
///
/// - 자동 dismiss 후에는 onUndo 호출되지 않음. 사용자가 액션 누르면 즉시 dismiss + onUndo 호출.
/// - 호출자는 이전 SnackBar 가 떠 있을 가능성을 고려해 [hideCurrentBeforeShow] 로 즉시 교체 가능.
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
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      duration: duration,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusM),
      ),
      action: SnackBarAction(label: '되돌리기', onPressed: onUndo),
    ),
  );
}
