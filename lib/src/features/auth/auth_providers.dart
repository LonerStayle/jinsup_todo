import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/remote/supabase_provider.dart';

/// Supabase 의 인증 상태 stream — Sign-in / Sign-out / 토큰 갱신 등 모든 이벤트.
final authStateProvider = StreamProvider<AuthState?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return Stream<AuthState?>.value(null);
  return client.auth.onAuthStateChange;
});

/// 현재 로그인된 사용자. Supabase 미설정 또는 미인증이면 null.
///
/// 초기 진입 시 [authStateProvider] 가 아직 emit 전이라도 [SupabaseClient.auth.currentUser]
/// (= 영속된 세션) 가 있다면 그것을 반환. 세션 영속은 supabase_flutter 가 자동.
final currentUserProvider = Provider<User?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return null;
  final asyncState = ref.watch(authStateProvider);
  return asyncState.maybeWhen(
    data: (state) => state?.session?.user ?? client.auth.currentUser,
    orElse: () => client.auth.currentUser,
  );
});
