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
