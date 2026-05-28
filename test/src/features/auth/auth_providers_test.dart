import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/data/local/app_database.dart';
import 'package:solo_todo/src/data/providers.dart';
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

  test('SignOutController — Supabase 미설정 환경에서도 db 정리는 진행', () async {
    final db = AppDatabase.memory();
    addTearDown(() async => db.close());
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    final controller = container.read(signOutControllerProvider);
    // auth 가 null 이라도 throw 없이 db clear 까지 진행.
    await controller.signOutAndClear();
    expect(await db.outboxDao.count(), 0);
  });
}
