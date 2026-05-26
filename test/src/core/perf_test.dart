import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/core/perf.dart';

void main() {
  test('ColdStartProbe.instance 접근 시 stopwatch 가 즉시 시작', () {
    final probe = ColdStartProbe.instance;
    expect(probe.elapsed, isNull); // markFirstFrame 전엔 null
    expect(probe.withinThreshold, isNull);
  });

  test('markFirstFrame 호출 후 elapsed + withinThreshold 노출 (1회 idempotent)', () {
    final probe = ColdStartProbe.instance;
    probe.markFirstFrame();
    final first = probe.elapsed;
    expect(first, isNotNull);
    expect(first!.isNegative, isFalse);

    // 두 번째 호출은 idempotent — elapsed 변경되지 않음.
    probe.markFirstFrame();
    expect(probe.elapsed, first);
  });

  test('임계값 1초 (sanity)', () {
    expect(ColdStartProbe.threshold, const Duration(seconds: 1));
  });
}
