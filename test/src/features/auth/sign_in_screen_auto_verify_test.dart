import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:solo_todo/src/core/theme.dart';
import 'package:solo_todo/src/features/auth/auth_service.dart';
import 'package:solo_todo/src/features/auth/sign_in_screen.dart';

/// 6자리 이상 OTP 가 입력된 후 300ms 동안 추가 입력이 없으면 자동으로 verifyEmailOtp
/// 가 호출되는지 검증. Supabase OTP 길이가 6~10 가변이라 정확한 길이를 client 가 모르므로
/// debounce 로 사용자가 입력을 멈춘 시점을 trigger 로 사용.
void main() {
  Future<_FakeAuthService> mount(WidgetTester tester) async {
    final fake = _FakeAuthService();
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authServiceProvider.overrideWithValue(fake)],
        child: MaterialApp(
          theme: AppTheme.mobileLight(),
          home: const SignInScreen(),
        ),
      ),
    );
    return fake;
  }

  Future<void> enterEmailAndContinue(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).first, 'me@example.com');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '코드 받기'));
    // sendEmailOtp 가 sync resolve (fake) → 다음 frame 에 step=otp.
    await tester.pump();
    await tester.pump();
  }

  testWidgets('OTP 5자리만 입력 → 300ms 후에도 자동 verify X', (tester) async {
    final fake = await mount(tester);
    await enterEmailAndContinue(tester);

    final otpField = find.byType(TextField).last;
    await tester.enterText(otpField, '12345');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(fake.verifyCalls, isEmpty, reason: '6자리 미만은 자동 trigger 안 됨');
  });

  testWidgets('OTP 6자리 입력 + 300ms idle → 자동 verify 1회', (tester) async {
    final fake = await mount(tester);
    await enterEmailAndContinue(tester);

    await tester.enterText(find.byType(TextField).last, '123456');
    await tester.pump();
    // debounce 직전엔 아직 호출 X.
    await tester.pump(const Duration(milliseconds: 200));
    expect(fake.verifyCalls, isEmpty);

    // debounce 통과 — 한 번 호출.
    await tester.pump(const Duration(milliseconds: 200));
    expect(fake.verifyCalls, ['123456']);
  });

  testWidgets('빠른 8자리 타이핑 → debounce 로 마지막 입력 후 한 번만 verify', (tester) async {
    final fake = await mount(tester);
    await enterEmailAndContinue(tester);

    final otpField = find.byType(TextField).last;

    // 6 → 7 → 8 자리로 빠르게 (간격 100ms — debounce 300ms 보다 짧게).
    await tester.enterText(otpField, '123456');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(otpField, '1234567');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(otpField, '12345678');
    await tester.pump();

    // 마지막 입력 후 debounce 통과.
    await tester.pump(const Duration(milliseconds: 350));

    expect(fake.verifyCalls, [
      '12345678',
    ], reason: '디바운스 — 중간 길이 (6, 7) 에서 fire 되지 않고 마지막 8자리만');
  });

  testWidgets('6자리 입력 후 backspace 로 5자리 만들면 idle 후에도 verify 안 됨', (
    tester,
  ) async {
    final fake = await mount(tester);
    await enterEmailAndContinue(tester);

    final otpField = find.byType(TextField).last;
    await tester.enterText(otpField, '123456');
    await tester.pump();
    // debounce 직전에 한 자 지움.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(otpField, '12345');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(fake.verifyCalls, isEmpty);
  });
}

/// AuthService 를 implements — Supabase 의존성 없이 verify 호출만 추적.
class _FakeAuthService implements AuthService {
  final List<String> verifyCalls = [];

  @override
  Future<void> sendEmailOtp(String email) async {}

  @override
  Future<AuthResponse> verifyEmailOtp({
    required String email,
    required String token,
  }) {
    verifyCalls.add(token);
    // 영원히 pending 으로 두면 _busy = true 유지 — 자동 trigger 재발화 방지에도 부합.
    return Completer<AuthResponse>().future;
  }

  @override
  Future<void> signOut() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
