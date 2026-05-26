import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/remote/supabase_provider.dart';

/// 이메일 매직링크 (one-time password) 기반 인증.
///
/// 매직링크 클릭 후 OS 로 돌아오는 deep link 처리는 supabase_flutter 가
/// 일부 자동 처리하지만, macOS/Android 모두 SETUP.html 의 가이드대로
/// URL scheme 등록 + Supabase Auth 설정의 redirect URL 일치가 필요하다.
class AuthService {
  AuthService(this._client);

  final SupabaseClient _client;

  /// 매직링크 발송. 사용자가 이메일에서 링크를 누르면 deep link 으로 앱이 열리고
  /// [Supabase.auth.onAuthStateChange] 가 signedIn 이벤트를 emit 한다.
  Future<void> signInWithEmailOtp(String email) {
    return _client.auth.signInWithOtp(email: email.trim());
  }

  Future<void> signOut() => _client.auth.signOut();
}

final authServiceProvider = Provider<AuthService?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : AuthService(client);
});
