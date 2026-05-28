import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/remote/supabase_provider.dart';

/// 이메일 **OTP 6자리 코드** 기반 인증.
///
/// 매직링크 흐름은 Supabase 의 Site URL 이 다른 앱과 공유 불가능해 채택하지 않는다.
/// 대신 [signInWithOtp] 가 자동으로 함께 발송하는 6자리 OTP 코드를 받아 [verifyOtp] 로
/// 검증한다. deep link / Site URL 완전 무관.
class AuthService {
  AuthService(this._client);

  final SupabaseClient _client;

  /// 이메일로 OTP 6자리 코드 발송. shouldCreateUser 가 true 면 신규 사용자도 자동 가입.
  Future<void> sendEmailOtp(String email) {
    return _client.auth.signInWithOtp(
      email: email.trim(),
      shouldCreateUser: true,
    );
  }

  /// 사용자가 입력한 6자리 코드 검증. 성공 시 세션 생성.
  Future<AuthResponse> verifyEmailOtp({
    required String email,
    required String token,
  }) {
    return _client.auth.verifyOTP(
      email: email.trim(),
      token: token.trim(),
      type: OtpType.email,
    );
  }

  Future<void> signOut() => _client.auth.signOut();
}

final authServiceProvider = Provider<AuthService?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : AuthService(client);
});
