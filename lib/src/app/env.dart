/// 컴파일 타임 환경변수 (`--dart-define-from-file=.env.local`).
///
/// 비어 있을 수 있으니 사용처에서 [isSupabaseConfigured] 등으로 가드한다.
class Env {
  const Env._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );
  static const String googleOAuthClientIdDesktop = String.fromEnvironment(
    'GOOGLE_OAUTH_CLIENT_ID_DESKTOP',
  );
  static const String googleOAuthClientIdAndroid = String.fromEnvironment(
    'GOOGLE_OAUTH_CLIENT_ID_ANDROID',
  );

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static bool get isGoogleCalendarConfigured =>
      googleOAuthClientIdDesktop.isNotEmpty ||
      googleOAuthClientIdAndroid.isNotEmpty;
}
