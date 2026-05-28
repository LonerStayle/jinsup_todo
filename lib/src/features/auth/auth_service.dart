import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/platform.dart';
import '../../data/remote/supabase_provider.dart';

/// 이메일 매직링크 (one-time password) 기반 인증.
///
/// 매직링크 클릭 후 OS 로 돌아오는 deep link 처리는 supabase_flutter 가
/// 자동 처리하지만, macOS/Android 모두 SETUP.html 의 가이드대로
/// URL scheme 등록 + Supabase Auth 설정의 Redirect URLs 화이트리스트 일치가 필요하다.
///
/// `emailRedirectTo` 를 명시하지 않으면 Supabase 가 Dashboard 의 Site URL 로 fallback —
/// 같은 프로젝트의 다른 앱이 Site URL 을 점유하고 있으면 매직링크가 엉뚱한 곳으로 간다.
/// 그래서 항상 우리 앱의 deep link URL 을 명시한다.
class AuthService {
  AuthService(this._client);

  final SupabaseClient _client;

  /// 매직링크 발송. 플랫폼별 redirect URL 명시.
  Future<void> signInWithEmailOtp(String email) {
    return _client.auth.signInWithOtp(
      email: email.trim(),
      emailRedirectTo: _emailRedirectTo,
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  /// 우리 앱의 deep link URL. Info.plist (macOS) / AndroidManifest intent-filter 와 일치.
  static String get _emailRedirectTo => AppPlatform.isDesktop
      ? 'io.supabase.solo_todo://login-callback'
      : 'com.goldenplanet.solo_todo://login-callback';
}

final authServiceProvider = Provider<AuthService?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : AuthService(client);
});
