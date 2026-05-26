import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../app/env.dart';
import '../../core/platform.dart';

/// Google OAuth (Calendar API 용) 셋업 + sign-in / sign-out.
///
/// CLAUDE.md 비전: macOS + Android 모두 사용. 두 플랫폼이 OAuth 클라이언트 id 가 다르므로
/// [Env.googleOAuthClientIdDesktop] / [Env.googleOAuthClientIdAndroid] 둘 다 가능.
/// 둘 중 하나라도 채워져 있으면 활성화.
///
/// google_sign_in 7.x 의 [GoogleSignIn.instance] 는 process 당 단일. [initialize]
/// 는 처음 1회만 호출.
class GoogleAuthService {
  GoogleAuthService(this._clientId);

  /// 현재 플랫폼의 client id. macOS desktop 이면 desktop, Android 면 android.
  /// 둘 다 비어 있으면 [GoogleAuthService] 자체가 만들어지지 않음 (provider null).
  final String _clientId;

  static const _calendarScope =
      'https://www.googleapis.com/auth/calendar.events';

  bool _initialized = false;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(clientId: _clientId);
    _initialized = true;
  }

  /// 사용자 명시적 sign-in. 성공 시 [GoogleSignInAccount] 반환. 사용자가 취소하거나
  /// 실패하면 [GoogleSignInException] / 일반 예외 throw.
  Future<GoogleSignInAccount> signIn() async {
    await _ensureInit();
    return GoogleSignIn.instance.authenticate();
  }

  /// Calendar 권한 (`calendar.events`) 인가 헤더. CalendarService 가 매 요청 직전 호출.
  /// 토큰 만료 시 자동 갱신은 google_sign_in 이 처리.
  Future<Map<String, String>?> authHeadersForCalendar(
    GoogleSignInAccount account,
  ) async {
    await _ensureInit();
    return account.authorizationClient.authorizationHeaders([_calendarScope]);
  }

  /// 백그라운드에서 자동 sign-in 시도 (이전 세션 복원). UI 가드용.
  Future<GoogleSignInAccount?> tryRestore() async {
    try {
      await _ensureInit();
      return await GoogleSignIn.instance.attemptLightweightAuthentication();
    } catch (e) {
      debugPrint('[solo_todo] Google 세션 복원 실패: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await _ensureInit();
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      debugPrint('[solo_todo] Google signOut 실패: $e');
    }
  }
}

/// 현재 플랫폼에 맞는 Google OAuth client id. 미설정이면 null.
String? _platformClientId() {
  if (AppPlatform.isDesktop) {
    final id = Env.googleOAuthClientIdDesktop;
    return id.isEmpty ? null : id;
  }
  final id = Env.googleOAuthClientIdAndroid;
  return id.isEmpty ? null : id;
}

/// [GoogleAuthService] 인스턴스. 환경변수 미설정 시 null — Calendar 연동 자체가 disabled.
final googleAuthServiceProvider = Provider<GoogleAuthService?>((ref) {
  final id = _platformClientId();
  return id == null ? null : GoogleAuthService(id);
});

/// 사용자에게 Calendar 연결 기능을 노출할지 결정하는 plain bool.
final googleCalendarAvailableProvider = Provider<bool>(
  (ref) => ref.watch(googleAuthServiceProvider) != null,
);
