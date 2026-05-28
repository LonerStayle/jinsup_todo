import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/providers.dart';
import '../../data/remote/supabase_provider.dart';
import 'auth_service.dart';

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

/// signOut + local 데이터 정리. UI 의 로그아웃 액션이 이 메서드를 호출한다.
///
/// `AuthService.signOut` 만 호출하면 Drift 의 todos / outbox 에 옛 user 의 데이터가
/// 남아 다음 user 가 sign-in 했을 때 그대로 노출된다 (Supabase row 와 곧 sync 되더라도
/// 첫 frame 동안 잠깐 보임). 이 컨트롤러가 두 작업을 한 곳에서 묶는다.
class SignOutController {
  SignOutController(this._ref);

  final Ref _ref;

  Future<void> signOutAndClear() async {
    final auth = _ref.read(authServiceProvider);
    if (auth != null) {
      await auth.signOut();
    }
    final db = _ref.read(appDatabaseProvider);
    await db.clearAllUserData();
  }
}

final signOutControllerProvider = Provider<SignOutController>(
  SignOutController.new,
);

/// **자동 cleanup listener** — currentUser id 가 바뀌면 옛 데이터 삭제.
///
/// 시나리오:
///   - 다른 user 로 sign-in (lastId != null, newId != lastId, 둘 다 non-null): 옛 데이터 삭제.
///   - 토큰 만료 / 외부 sign-out (lastId != null, newId == null): supabase_flutter 의 자동
///     refresh 가 실패하면 onAuthStateChange 가 signedOut 을 emit → currentUserProvider 가
///     null 로 떨어진다. outbox 에 남은 옛 user 의 미push 변경이 다음 sign-in 시 다른
///     계정으로 push 되는 사고를 막기 위해 여기서도 clearAllUserData.
///   - 첫 sign-in (lastId == null, newId != null): 정상 진입 — clear 안 함.
///
/// in-memory 한정 — 앱 재시작 후엔 lastId 가 reset 되므로 같은 세션 안에서만 동작.
/// 1인 사용자 비전이라 충분.
///
/// AppShell 또는 _AuthGate 에서 `ref.watch(userChangeCleanupProvider)` 로 활성화.
final userChangeCleanupProvider = Provider<void>((ref) {
  String? lastId;
  ref.listen<User?>(currentUserProvider, (prev, next) async {
    final newId = next?.id;
    // 이전이 sign-in 상태였는데 user 가 바뀌었거나(다른 계정) sign-out 됐다면 clear.
    final wasSignedIn = lastId != null;
    final userChanged = newId != lastId;
    if (wasSignedIn && userChanged) {
      final db = ref.read(appDatabaseProvider);
      await db.clearAllUserData();
    }
    lastId = newId;
  }, fireImmediately: true);
});
