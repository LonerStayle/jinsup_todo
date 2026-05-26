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

  group('FpsMonitor', () {
    test('초기 상태 — 0 frames, jankRate 0', () {
      final m = FpsMonitor.instance;
      m.snapshotAndReset(); // 다른 test 가 영향 끼쳤을 수 있으니 초기화
      expect(m.totalFrames, 0);
      expect(m.jankyFrames, 0);
      expect(m.jankRate, 0);
    });

    test('60fps frame budget = 16.667ms (sanity)', () {
      expect(FpsMonitor.frameBudget.inMicroseconds, 16667);
    });

    test('snapshotAndReset 이 누적값 반환 + 카운터 0 초기화', () {
      final m = FpsMonitor.instance..snapshotAndReset();
      // 외부 frame 이벤트 발생이 없어 totalFrames 는 그대로 0.
      final snap = m.snapshotAndReset();
      expect(snap.total, 0);
      expect(snap.janky, 0);
      expect(snap.rate, 0);
      expect(m.totalFrames, 0);
    });
  });
}
