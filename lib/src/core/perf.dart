import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// 콜드 스타트 측정 — `main()` 진입부터 첫 frame 렌더 완료까지의 wall clock.
///
/// CLAUDE.md 비전상 임계값 1 초. 초과 시 debug 로그로 경고하고 elapsed 값을 보존
/// (대표님이 release 빌드에서 직접 확인하거나 차후 메트릭 적재 시 사용).
class ColdStartProbe {
  ColdStartProbe._() : _sw = Stopwatch()..start();

  static final ColdStartProbe instance = ColdStartProbe._();

  final Stopwatch _sw;
  Duration? _elapsed;

  /// 임계값. 초과 시 debugPrint 경고.
  static const threshold = Duration(seconds: 1);

  /// 첫 frame 후 1 회 호출. 이후 호출은 idempotent (no-op).
  void markFirstFrame() {
    if (_elapsed != null) return;
    _sw.stop();
    _elapsed = _sw.elapsed;
    final ms = _elapsed!.inMilliseconds;
    if (_elapsed! > threshold) {
      debugPrint(
        '[solo_todo] ⚠️ cold start ${ms}ms 가 임계값 ${threshold.inMilliseconds}ms 를 초과했습니다.',
      );
    } else {
      debugPrint(
        '[solo_todo] cold start = ${ms}ms (< ${threshold.inMilliseconds}ms ✓)',
      );
    }
  }

  /// 측정값. markFirstFrame 호출 전엔 null.
  Duration? get elapsed => _elapsed;

  /// 임계값 통과 여부. 미측정이면 null.
  bool? get withinThreshold {
    final e = _elapsed;
    if (e == null) return null;
    return e <= threshold;
  }
}

/// [WidgetsBinding] 의 첫 frame 콜백에 [ColdStartProbe.markFirstFrame] 등록.
void scheduleColdStartCapture() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    ColdStartProbe.instance.markFirstFrame();
  });
}

/// 60fps frame budget 감시. SchedulerBinding.addTimingsCallback 으로 모든 frame 의
/// totalSpan 을 받아 16.67ms 초과 (jank) 카운트.
///
/// 측정값은 [jankRate] / [totalFrames] / [jankyFrames] 로 노출. 1 분 트레이스 후
/// [snapshotAndReset] 호출로 누적 stat dump 후 0 초기화.
class FpsMonitor {
  FpsMonitor._();

  static final FpsMonitor instance = FpsMonitor._();

  /// 60fps frame budget = 1000 / 60 ≈ 16.667ms.
  static const Duration frameBudget = Duration(microseconds: 16667);

  int _total = 0;
  int _janky = 0;
  bool _attached = false;

  void start() {
    if (_attached) return;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    _attached = true;
  }

  void stop() {
    if (!_attached) return;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _attached = false;
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      _total++;
      if (t.totalSpan > frameBudget) _janky++;
    }
  }

  int get totalFrames => _total;
  int get jankyFrames => _janky;

  /// 0 (모든 frame 60fps 통과) ~ 1 (전부 jank). 측정 0 건이면 0.
  double get jankRate => _total == 0 ? 0 : _janky / _total;

  /// 현재 누적 stat 의 사람-읽기 문자열. 디버그/SETUP.html 안내용.
  String describe() {
    final rate = (jankRate * 100).toStringAsFixed(1);
    return 'frames=$_total, janky=$_janky, jankRate=$rate%';
  }

  /// 누적 stat 을 반환하면서 카운터 초기화. 1 분 트레이스 후 호출 권장.
  ({int total, int janky, double rate}) snapshotAndReset() {
    final snap = (total: _total, janky: _janky, rate: jankRate);
    _total = 0;
    _janky = 0;
    return snap;
  }
}
