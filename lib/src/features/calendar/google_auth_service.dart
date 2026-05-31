import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis_auth/auth_io.dart' as gauth;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../app/env.dart';
import '../../core/platform.dart';

/// Calendar 이벤트 CRUD 에 필요한 scope (읽기/쓰기 포함).
const calendarEventsScope = 'https://www.googleapis.com/auth/calendar.events';
const _scopes = [calendarEventsScope];

/// 플랫폼 중립 Calendar 인증 추상화.
///
/// macOS desktop 과 Android 는 OAuth 방식이 **근본적으로 다르다**:
/// - **Android** → [MobileCalendarAuth]: google_sign_in (Credential Manager).
///   패키지명 + SHA-1 로 Google Cloud Console 에서 자동 매칭.
/// - **macOS** → [DesktopCalendarAuth]: google_sign_in 의 GIDSignIn 은 토큰을
///   키체인에 저장하는데, 키체인 액세스 그룹 접근에는 유효한 app-identifier 서명
///   (= Apple 개발팀) 이 필요하다. ad-hoc 서명(로컬 개발) 에선 "keychain error" 로
///   실패한다. 그래서 macOS 는 googleapis_auth 의 **데스크톱 OAuth 플로우**
///   (브라우저 동의 → localhost 리다이렉트 → refresh token 로컬 저장) 로 우회한다.
///   키체인·Apple 서명이 일절 필요 없다.
abstract class CalendarAuth {
  /// Calendar API 호출용 인증된 [http.Client]. 사용자가 동의를 거부/취소하면 null.
  /// 호출자가 사용 후 반드시 close() 한다.
  Future<http.Client?> authedClient();

  Future<void> signOut();
}

// ---------------------------------------------------------------------------
// Android — google_sign_in (Credential Manager) 기반
// ---------------------------------------------------------------------------

/// 헤더만 주입하는 얇은 http.Client (google_sign_in 인가 헤더용).
class _HeaderClient extends http.BaseClient {
  _HeaderClient(this._headers);

  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

class MobileCalendarAuth implements CalendarAuth {
  MobileCalendarAuth(this._clientId);

  /// Android 활성화 게이트용. 실제 매칭은 SHA-1 + 패키지명으로 이뤄지므로 값 자체는
  /// initialize 에 넘기지 않는다 (google_sign_in 7.x Credential Manager 규칙).
  // ignore: unused_field
  final String _clientId;

  bool _initialized = false;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    // Android 7.x 는 serverClientId(웹 클라이언트 ID) 필수. 미설정이면 명확한 에러로
    // 안내되도록 그대로 넘긴다 (빈 문자열 → null).
    final serverClientId = Env.googleOAuthServerClientId;
    await GoogleSignIn.instance.initialize(
      serverClientId: serverClientId.isEmpty ? null : serverClientId,
    );
    _initialized = true;
  }

  Future<GoogleSignInAccount?> _tryRestore() async {
    try {
      return await GoogleSignIn.instance.attemptLightweightAuthentication();
    } catch (e) {
      debugPrint('[solo_todo] Google 세션 복원 실패: $e');
      return null;
    }
  }

  @override
  Future<http.Client?> authedClient() async {
    await _ensureInit();
    final account =
        await _tryRestore() ??
        await GoogleSignIn.instance.authenticate(scopeHint: _scopes);
    final client = account.authorizationClient;
    // calendar scope 미부여 시 증분 동의 프롬프트. 거부 시 throw.
    final existing = await client.authorizationForScopes(_scopes);
    if (existing == null) {
      await client.authorizeScopes(_scopes);
    }
    final headers = await client.authorizationHeaders(_scopes);
    if (headers == null) return null;
    return _HeaderClient(headers);
  }

  @override
  Future<void> signOut() async {
    try {
      await _ensureInit();
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      debugPrint('[solo_todo] Google signOut 실패: $e');
    }
  }
}

// ---------------------------------------------------------------------------
// macOS — googleapis_auth 데스크톱 OAuth 플로우 (키체인/서명 불필요)
// ---------------------------------------------------------------------------

class DesktopCalendarAuth implements CalendarAuth {
  DesktopCalendarAuth({required this.clientId, required this.clientSecret});

  /// "Desktop app" 타입 OAuth 클라이언트 (client_secret 동반). localhost 리다이렉트를
  /// Google 이 자동 허용하므로 별도 redirect URI 등록 불필요.
  final String clientId;
  final String clientSecret;

  gauth.ClientId get _id => gauth.ClientId(clientId, clientSecret);

  @override
  Future<http.Client?> authedClient() async {
    // 1) 저장된 refresh token 으로 무프롬프트 갱신 시도.
    final refreshToken = await _loadRefreshToken();
    if (refreshToken != null) {
      try {
        final base = http.Client();
        final stale = gauth.AccessCredentials(
          gauth.AccessToken(
            'Bearer',
            'expired',
            DateTime.now().toUtc().subtract(const Duration(hours: 1)),
          ),
          refreshToken,
          _scopes,
        );
        final fresh = await gauth.refreshCredentials(_id, stale, base);
        return gauth.autoRefreshingClient(_id, fresh, base);
      } catch (e) {
        debugPrint('[solo_todo] Calendar refresh 실패 → 브라우저 재동의로 진행: $e');
        // 토큰이 무효 — 지우고 동의 플로우로.
        await _clearRefreshToken();
      }
    }
    // 2) 브라우저 동의 (localhost 임시 서버로 코드 수신).
    try {
      final client = await gauth.clientViaUserConsent(_id, _scopes, _open);
      final rt = client.credentials.refreshToken;
      if (rt != null && rt.isNotEmpty) await _saveRefreshToken(rt);
      return client;
    } catch (e) {
      debugPrint('[solo_todo] Calendar OAuth 동의 실패/취소: $e');
      return null;
    }
  }

  /// macOS 기본 브라우저로 동의 URL 열기 (url_launcher 의존 없이 `open`).
  void _open(String url) {
    Process.run('open', [url]);
  }

  @override
  Future<void> signOut() => _clearRefreshToken();

  // --- refresh token 로컬 저장 (키체인 X — 평문 파일, 1인 개인 앱 전제) ---------

  Future<File> _tokenFile() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'google_calendar_token.json'));
  }

  Future<String?> _loadRefreshToken() async {
    try {
      final f = await _tokenFile();
      if (!await f.exists()) return null;
      final map = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      final rt = map['refresh_token'] as String?;
      return (rt == null || rt.isEmpty) ? null : rt;
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveRefreshToken(String token) async {
    try {
      final f = await _tokenFile();
      await f.writeAsString(jsonEncode({'refresh_token': token}));
    } catch (e) {
      debugPrint('[solo_todo] refresh token 저장 실패: $e');
    }
  }

  Future<void> _clearRefreshToken() async {
    try {
      final f = await _tokenFile();
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// 현재 플랫폼에 맞는 [CalendarAuth]. 환경변수 미설정 시 null — Calendar 연동 비활성.
final calendarAuthProvider = Provider<CalendarAuth?>((ref) {
  if (AppPlatform.isDesktop) {
    final id = Env.googleOAuthClientIdDesktop;
    final secret = Env.googleOAuthClientSecretDesktop;
    // 데스크톱 플로우는 client id + secret 둘 다 필요.
    if (id.isEmpty || secret.isEmpty) return null;
    return DesktopCalendarAuth(clientId: id, clientSecret: secret);
  }
  final id = Env.googleOAuthClientIdAndroid;
  return id.isEmpty ? null : MobileCalendarAuth(id);
});

/// 사용자에게 Calendar 연결 기능을 노출할지 결정하는 plain bool.
final googleCalendarAvailableProvider = Provider<bool>(
  (ref) => ref.watch(calendarAuthProvider) != null,
);
