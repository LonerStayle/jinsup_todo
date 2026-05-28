import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:solo_todo/src/features/auth/auth_error_message.dart';

void main() {
  group('friendlyAuthErrorMessage', () {
    test('HTTP 429 rate limit → 1분에 한 번 안내', () {
      const err = AuthException('Too many requests', statusCode: '429');
      final msg = friendlyAuthErrorMessage(err, forVerify: false);
      expect(msg, contains('1분에 한 번'));
    });

    test('over_email_send_rate_limit 메시지 → 동일 안내', () {
      const err = AuthException(
        'For security purposes, you can only request this once every 60 seconds — over_email_send_rate_limit',
      );
      final msg = friendlyAuthErrorMessage(err, forVerify: false);
      expect(msg, contains('1분에 한 번'));
    });

    test('invalid email (forVerify=false) → 형식 안내', () {
      const err = AuthException('Invalid email address');
      final msg = friendlyAuthErrorMessage(err, forVerify: false);
      expect(msg, contains('이메일 주소 형식'));
    });

    test('verify 단계의 invalid token → 새 코드 안내', () {
      const err = AuthException('Token has expired or is invalid');
      final msg = friendlyAuthErrorMessage(err, forVerify: true);
      expect(msg, contains('새 코드'));
    });

    test('일반 Exception → forVerify 분기별 fallback 문구', () {
      final err = Exception('network down');
      expect(
        friendlyAuthErrorMessage(err, forVerify: false),
        contains('코드 발송'),
      );
      expect(friendlyAuthErrorMessage(err, forVerify: true), contains('코드 확인'));
    });

    test('AuthException 의 알려지지 않은 메시지 → 원본 message 반환', () {
      const err = AuthException('Unknown server issue');
      expect(
        friendlyAuthErrorMessage(err, forVerify: false),
        'Unknown server issue',
      );
    });
  });
}
