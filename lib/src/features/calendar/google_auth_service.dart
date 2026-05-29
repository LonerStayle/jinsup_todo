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
///
/// ⚠️ 7.x 의 핵심 변화: **인증(authenticate) 과 인가(authorize) 분리**.
/// `authenticate()` 는 "누구인지"(identity) 만 확인하며 어떤 scope 도 부여하지 않는다.
/// Calendar 같은 추가 scope 는 반드시 [authorizationClient]`.authorizeScopes()`
/// 로 **증분 동의(incremental consent)** 를 받아야 access token 에 붙는다.
/// `authorizationHeaders()` / `authorizationForScopes()` 는 *이미 부여된* scope 에
/// 대해서만 (사용자 상호작용 없이) 헤더를 돌려주고, 미부여 시 null 을 반환한다.
/// → 과거 코드는 `authorizeScopes` 호출이 없어 Android 에서 calendar 권한이 절대
///   부여되지 않았고, 이것이 "권한 없음" 의 코드 측 근본 원인이었다.
class GoogleAuthService {
  GoogleAuthService(this._clientId);

  /// 현재 플랫폼의 client id. macOS desktop 이면 desktop, Android 면 android.
  /// 둘 다 비어 있으면 [GoogleAuthService] 자체가 만들어지지 않음 (provider null).
  ///
  /// ⚠️ Android: google_sign_in 7.x 는 Credential Manager 기반이라 Android OAuth
  /// client 를 **코드의 clientId 로 받지 않는다** — 패키지명 + SHA-1 로 Google
  /// Cloud Console 에서 자동 매칭된다. 그래서 [_ensureInit] 에서 Android 일 때는
  /// clientId 를 넘기지 않는다 (desktop/iOS 계열만 clientId 필요).
  final String _clientId;

  /// Calendar 이벤트 CRUD 에 필요한 scope. 읽기/쓰기 포함.
  static const _calendarScope =
      'https://www.googleapis.com/auth/calendar.events';
  static const _scopes = [_calendarScope];

  bool _initialized = false;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    // Android 는 clientId 를 넘기면 안 됨 (SHA-1 기반 자동 매칭). desktop 등은 필요.
    if (AppPlatform.isDesktop) {
      await GoogleSignIn.instance.initialize(clientId: _clientId);
    } else {
      await GoogleSignIn.instance.initialize();
    }
    _initialized = true;
  }

  /// 사용자 명시적 sign-in (identity only). 성공 시 [GoogleSignInAccount] 반환.
  /// 사용자가 취소하거나 실패하면 [GoogleSignInException] / 일반 예외 throw.
  ///
  /// 주의: 이 호출만으로는 Calendar 권한이 부여되지 않는다. scope 부여는
  /// [authHeadersForCalendar] 내부의 [_ensureCalendarAuthorized] 가 담당.
  Future<GoogleSignInAccount> signIn() async {
    await _ensureInit();
    // scopeHint 로 지원 플랫폼에선 인증과 동시에 scope 동의를 유도. 미지원 플랫폼은
    // 무시되고 이후 authorizeScopes 가 별도 동의 프롬프트를 띄운다.
    return GoogleSignIn.instance.authenticate(scopeHint: _scopes);
  }

  /// Calendar scope 가 부여돼 있는지 확인하고, 없으면 증분 동의 프롬프트를 띄워 부여.
  /// 부여 완료 후 인가 헤더를 반환. 사용자가 동의를 거부하면 예외 전파.
  Future<Map<String, String>?> _ensureCalendarAuthorized(
    GoogleSignInAccount account,
  ) async {
    final client = account.authorizationClient;
    // 1) 이미 부여된 경우 — 사용자 상호작용 없이 헤더 획득.
    final existing = await client.authorizationForScopes(_scopes);
    if (existing != null) {
      return client.authorizationHeaders(_scopes);
    }
    // 2) 미부여 — 증분 동의 프롬프트 (Android 는 사용자 상호작용 필요). 거부 시 throw.
    await client.authorizeScopes(_scopes);
    return client.authorizationHeaders(_scopes);
  }

  /// Calendar 권한 (`calendar.events`) 인가 헤더. CalendarService 가 매 요청 직전 호출.
  /// 토큰 만료 시 자동 갱신은 google_sign_in 이 처리.
  /// scope 미부여 시 증분 동의 프롬프트를 띄운다 (7.x 핵심 흐름).
  Future<Map<String, String>?> authHeadersForCalendar(
    GoogleSignInAccount account,
  ) async {
    await _ensureInit();
    return _ensureCalendarAuthorized(account);
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
