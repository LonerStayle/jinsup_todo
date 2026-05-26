import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/app/env.dart';

void main() {
  group('Env (테스트 환경엔 --dart-define 이 없으므로 모든 값이 빈 문자열)', () {
    test('isSupabaseConfigured == false', () {
      expect(Env.isSupabaseConfigured, isFalse);
    });

    test('isGoogleCalendarConfigured == false', () {
      expect(Env.isGoogleCalendarConfigured, isFalse);
    });

    test('missingKeys 가 Supabase 2 키 + Google 2 키 모두 포함', () {
      expect(Env.missingKeys, const [
        'SUPABASE_URL',
        'SUPABASE_ANON_KEY',
        'GOOGLE_OAUTH_CLIENT_ID_DESKTOP',
        'GOOGLE_OAUTH_CLIENT_ID_ANDROID',
      ]);
    });

    test('diagnostics() 가 누락 키 목록 + .env.example 안내 포함', () {
      final msg = Env.diagnostics();
      expect(msg, isNotNull);
      expect(msg, contains('SUPABASE_URL'));
      expect(msg, contains('SUPABASE_ANON_KEY'));
      expect(msg, contains('GOOGLE_OAUTH_CLIENT_ID_DESKTOP'));
      expect(msg, contains('GOOGLE_OAUTH_CLIENT_ID_ANDROID'));
      expect(msg, contains('.env.example'));
    });
  });
}
