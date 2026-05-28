import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:solo_todo/src/data/local/app_database.dart';
import 'package:solo_todo/src/data/providers.dart';
import 'package:solo_todo/src/domain/category.dart';
import 'package:solo_todo/src/domain/todo.dart';
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

  group('userChangeCleanupProvider — 토큰 만료/sign-out 자동 cleanup', () {
    User fakeUser(String id) => User(
      id: id,
      appMetadata: const {},
      userMetadata: const {},
      aud: '',
      createdAt: '2026-05-27T00:00:00.000Z',
    );

    Future<void> seed(AppDatabase db) async {
      await db.todosDao.upsert(_makeTodo());
    }

    test('sign-in → sign-out 전이 시 clearAllUserData 트리거', () async {
      final db = AppDatabase.memory();
      addTearDown(() async => db.close());
      final fakeUserState = StateController<User?>(fakeUser('u1'));
      addTearDown(fakeUserState.dispose);
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentUserProvider.overrideWith((ref) {
            // listenable 흉내 — StateController.stream 을 watch 할 수 없으니
            // ref.read 만으로는 동적이 안 되어 별도 provider 로 wrap.
            return fakeUserState.value;
          }),
        ],
      );
      addTearDown(container.dispose);

      await seed(db);
      expect(await db.todosDao.getById('seed'), isNotNull);

      // listener 활성화 — 초기 emit (u1) 은 lastId=null → skip 이어야 함.
      container.read(userChangeCleanupProvider);
      await Future<void>.delayed(Duration.zero);
      expect(
        await db.todosDao.getById('seed'),
        isNotNull,
        reason: '첫 sign-in 시 clear 되면 안 됨',
      );

      // sign-out 시뮬레이션 — provider 의 reactive 갱신을 위해 invalidate.
      fakeUserState.value = null;
      container.invalidate(currentUserProvider);
      container.read(currentUserProvider); // 강제 reread + listener 발화
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        await db.todosDao.getById('seed'),
        isNull,
        reason: 'sign-out (newId == null) 시 clearAllUserData 가 호출되어야 함',
      );
    });
  });
}

class StateController<T> {
  StateController(this.value);
  T value;
  void dispose() {}
}

Todo _makeTodo() => Todo(
  id: 'seed',
  title: 'x',
  category: Category.daily,
  dueAt: null,
  doneAt: null,
  createdAt: DateTime.utc(2026, 5, 27, 9),
  updatedAt: DateTime.utc(2026, 5, 27, 9),
  calendarEventId: null,
);
