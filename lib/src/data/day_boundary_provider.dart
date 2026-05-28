import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

/// "오늘" 의 시작 (자정) 을 들고 있는 reactive 값.
///
/// - 앱 시작 시 1회 즉시 emit (현재 자정).
/// - 다음 자정 도달 시 Timer 가 자동으로 state 를 다음날 자정으로 갱신.
/// - 의존하는 [watchTodayTodosProvider] / [carryoverCountProvider] 가 자동 재계산 →
///   미체크 항목 자동 이월 + 어제 체크된 항목 자동 hide 가 자정에 발화.
class DayBoundaryNotifier extends Notifier<DateTime> {
  Timer? _timer;

  @override
  DateTime build() {
    ref.onDispose(() => _timer?.cancel());
    final now = ref.read(nowProvider)();
    _scheduleNext(now);
    return DateTime(now.year, now.month, now.day);
  }

  void _scheduleNext(DateTime now) {
    final today0 = DateTime(now.year, now.month, now.day);
    final tomorrow0 = today0.add(const Duration(days: 1));
    final until = tomorrow0.difference(now);
    _timer?.cancel();
    // race 가드:
    //   - 자정 직후 일정 마진을 두지 않으면 다른 비동기와 동시 시각에 race 가능 → +1s
    //   - 만약 _tick 이 자정보다 약간 일찍 fire 해 nowProvider 가 자정 직전을 반환하면
    //     until 이 거의 0 또는 음수가 되어 무한 즉시-재예약 위험 → 최소 1초 보장.
    final base = until > Duration.zero ? until : Duration.zero;
    _timer = Timer(base + const Duration(seconds: 1), _tick);
  }

  void _tick() {
    final fresh = ref.read(nowProvider)();
    final newDay = DateTime(fresh.year, fresh.month, fresh.day);
    // newDay 가 현재 state 보다 뒤일 때만 갱신.
    // 자정 직전에 잘못 fire 한 경우 state 가 어제로 후퇴하는 것을 막는다.
    if (newDay.isAfter(state)) {
      state = newDay;
    }
    _scheduleNext(fresh);
  }

  /// 테스트에서 외부에서 강제 트리거. 일반 코드는 호출하지 않는다.
  @visibleForTesting
  void debugForceTick() => _tick();
}

final currentDayProvider = NotifierProvider<DayBoundaryNotifier, DateTime>(
  DayBoundaryNotifier.new,
);

/// "다음 자정까지 남은 Duration" — DayBoundaryNotifier 내부 로직과 동일 규칙.
/// 단위 테스트가 schedule 시간을 검증할 때 사용.
Duration nextMidnightFrom(DateTime now) {
  final today0 = DateTime(now.year, now.month, now.day);
  final tomorrow0 = today0.add(const Duration(days: 1));
  return tomorrow0.difference(now);
}
