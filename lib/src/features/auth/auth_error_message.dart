import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase auth 호출 실패를 사용자 친화 한국어 메시지로 변환.
///
/// 분기:
///   - rate limit (HTTP 429 / "over_email_send_rate_limit" / "rate" / "limit") →
///     "1분에 한 번만…" 안내
///   - invalid email → "이메일 주소 형식을 확인…"
///   - OTP 단계의 만료/불일치 → "코드가 일치하지 않거나 만료…"
///   - 그 외 → generic + 원인 추적용 toString
String friendlyAuthErrorMessage(Object err, {required bool forVerify}) {
  if (err is AuthException) {
    final code = err.statusCode ?? '';
    final msg = err.message.toLowerCase();
    final isRateLimit =
        code == '429' ||
        msg.contains('over_email_send_rate_limit') ||
        msg.contains('too many') ||
        (msg.contains('rate') && msg.contains('limit'));
    if (isRateLimit) {
      return '잠시 후 다시 시도해 주십시오. (1분에 한 번만 코드를 받을 수 있어요)';
    }
    if (!forVerify && msg.contains('invalid') && msg.contains('email')) {
      return '이메일 주소 형식을 확인해 주십시오.';
    }
    if (forVerify &&
        (msg.contains('invalid') ||
            msg.contains('expired') ||
            msg.contains('token'))) {
      return '코드가 일치하지 않거나 만료됐어요. 새 코드를 받아 주십시오.';
    }
    return err.message;
  }
  return forVerify
      ? '코드 확인에 실패했어요. 잠시 후 다시 시도해 주십시오.'
      : '코드 발송에 실패했어요. 잠시 후 다시 시도해 주십시오.';
}
