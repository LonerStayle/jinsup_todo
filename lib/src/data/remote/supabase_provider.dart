import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/env.dart';

/// `main()` 에서 1회 호출. [Env] 검증 후 Supabase 초기화.
///
/// env 누락 시 [debugPrint] 만 출력하고 false 반환 — 앱 자체는 로컬 only 로 정상 동작.
/// 초기화 실패 (네트워크 / 자격 오류) 도 graceful — fatal 아님.
Future<bool> initSupabaseFromEnv() async {
  if (!Env.isSupabaseConfigured) {
    debugPrint(
      '[solo_todo] Supabase 환경변수 미설정 — local-only 모드로 시작합니다. '
      '.env.local 에 SUPABASE_URL + SUPABASE_ANON_KEY 를 채워 주십시오.',
    );
    return false;
  }
  try {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
    return true;
  } catch (e) {
    debugPrint('[solo_todo] Supabase 초기화 실패 — local-only 모드 fallback: $e');
    return false;
  }
}

/// 초기화된 [SupabaseClient] 또는 null (env 미설정 / 초기화 실패).
final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  if (!Env.isSupabaseConfigured) return null;
  try {
    return Supabase.instance.client;
  } catch (_) {
    return null;
  }
});

/// Supabase 기능 (인증 / 동기화 / Realtime) 이 사용 가능한지.
final supabaseEnabledProvider = Provider<bool>(
  (ref) => ref.watch(supabaseClientProvider) != null,
);
