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
        final until = nextMidnightFrom(clock.now()) + const Duration(seconds: 2);
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
  });
}

extension on DateTime {
  DateTime get startOfDay => DateTime(year, month, day);
}
