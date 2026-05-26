import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/features/auth/auth_providers.dart';
import 'package:solo_todo/src/features/auth/auth_service.dart';

void main() {
  test('Supabase 미설정 (test 환경) → currentUserProvider == null', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(currentUserProvider), isNull);
  });

  test('Supabase 미설정 → authServiceProvider == null (호출자가 null check)', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(authServiceProvider), isNull);
  });

  test('authStateProvider — Supabase 미설정 시 AsyncData(null) 즉시 emit', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(authStateProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero); // microtask drain
    final value = container.read(authStateProvider);
    expect(value.hasValue, isTrue);
    expect(value.value, isNull);
  });
}
