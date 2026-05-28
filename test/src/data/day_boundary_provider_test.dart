import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/data/day_boundary_provider.dart';
import 'package:solo_todo/src/data/providers.dart';

void main() {
  group('nextMidnightFrom', () {
    test('낮 10시 → 다음 자정까지 14시간', () {
      final now = DateTime(2026, 5, 27, 10, 0);
      expect(nextMidnightFrom(now), const Duration(hours: 14));
    });

    test('자정 직후 (0:01) → 다음 자정까지 23h59m', () {
      final now = DateTime(2026, 5, 27, 0, 1);
      expect(nextMidnightFrom(now), const Duration(hours: 23, minutes: 59));
    });

    test('자정 직전 (23:59:50) → 다음 자정까지 10초', () {
      final now = DateTime(2026, 5, 27, 23, 59, 50);
      expect(nextMidnightFrom(now), const Duration(seconds: 10));
    });
  });

  group('currentDayProvider (Notifier + Timer)', () {
    test('초기 build 시 오늘 자정 emit', () {
      final container = ProviderContainer(
        overrides: [
          nowProvider.overrideWithValue(() => DateTime(2026, 5, 27, 10)),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(currentDayProvider), DateTime(2026, 5, 27, 0, 0));
    });

    test('자정 지나면 state 가 다음날로 갱신 (fake clock + clock.now 주입)', () {
      fakeAsync((async) {
        // nowProvider 가 fake clock 의 now 를 반환하도록.
        final container = ProviderContainer(
          overrides: [nowProvider.overrideWithValue(() => clock.now())],
        );
        addTearDown(container.dispose);

        expect(container.read(currentDayProvider), clock.now().startOfDay);

        // 자정 + 안전 마진 통과까지만 elapse (단일 step).
        // 더 흘리면 다음 자정 Timer 도 fire 되어 무한 추론 가능.
        final until =
            nextMidnightFrom(clock.now()) + const Duration(seconds: 2);
        async.elapse(until);

        expect(
          container.read(currentDayProvider),
          clock.now().startOfDay,
          reason: '자정 도달 후 state 가 fake clock 의 새 today0 로 갱신되어야 함',
        );
      }, initialTime: DateTime(2026, 5, 27, 23, 59, 30));
    });

    test('dispose 시 Timer cancel — leak 없음', () {
      fakeAsync((async) {
        final container = ProviderContainer(
          overrides: [nowProvider.overrideWithValue(() => clock.now())],
        );
        container.read(currentDayProvider); // init
        expect(async.pendingTimers, hasLength(1));

        container.dispose();
        expect(async.pendingTimers, isEmpty);
      }, initialTime: DateTime(2026, 5, 27, 10));
    });

    test('자정 직전에 _tick 이 잘못 fire 해도 state 가 후퇴하지 않음', () {
      // OS Timer 가 자정보다 약간 일찍 fire 한 상황을 _tick 직접 호출로 시뮬레이션.
      var fakeNow = DateTime(2026, 5, 27, 23, 59, 59, 900);
      final container = ProviderContainer(
        overrides: [nowProvider.overrideWithValue(() => fakeNow)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(currentDayProvider.notifier);
      expect(container.read(currentDayProvider), DateTime(2026, 5, 27, 0, 0));

      // 자정 직전에 잘못 fire — fresh 가 같은 날을 가리킴.
      notifier.debugForceTick();
      expect(
        container.read(currentDayProvider),
        DateTime(2026, 5, 27, 0, 0),
        reason: 'newDay 가 현재 state 와 같으면 갱신하지 않음 — 후퇴 방지',
      );

      // 이제 진짜 자정 통과.
      fakeNow = DateTime(2026, 5, 28, 0, 0, 5);
      notifier.debugForceTick();
      expect(container.read(currentDayProvider), DateTime(2026, 5, 28, 0, 0));
    });

    test('자정 직전 fresh 라 until 이 거의 0 이어도 _scheduleNext 의 delay 최소 1초 보장', () {
      fakeAsync((async) {
        // 자정까지 0.05초 — until 이 매우 작은 상황.
        final container = ProviderContainer(
          overrides: [nowProvider.overrideWithValue(() => clock.now())],
        );
        addTearDown(container.dispose);

        final notifier = container.read(currentDayProvider.notifier);

        // _scheduleNext 이 _tick 안에서 다시 호출되도록 한 번 forceTick.
        // 이전 timer 가 cancel 되고 새 timer 가 schedule 됨.
        notifier.debugForceTick();

        // 새 pendingTimer 가 최소 1초 이상이어야 한다. fake_async 의 다음 timer 까지
        // 0.5 초만 elapse 해도 fire 되면 안 됨 (== 무한 재호출 방지 검증).
        final beforeTickState = container.read(currentDayProvider);
        async.elapse(const Duration(milliseconds: 500));
        expect(
          container.read(currentDayProvider),
          beforeTickState,
          reason: '0.5초 안에 timer 가 fire 되어 state 가 또 바뀌면 무한 재예약 의심',
        );
      }, initialTime: DateTime(2026, 5, 27, 23, 59, 59, 950));
    });
  });
}

extension on DateTime {
  DateTime get startOfDay => DateTime(year, month, day);
}
