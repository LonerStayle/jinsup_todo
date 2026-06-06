import 'package:flutter/services.dart';

import '../../core/platform.dart';

/// macOS '로그인 시 자동 실행' 토글의 네이티브 백엔드 래퍼.
///
/// macOS 13+ 의 `SMAppService.mainApp` 을 [MethodChannel] (`app.haru/launch_at_login`)
/// 로 호출한다 (네이티브 구현은 `macos/Runner/MainFlutterWindow.swift`).
///
/// - macOS 외 플랫폼에서는 모든 메서드가 no-op (항상 false).
/// - 실제 register/unregister 는 정식 서명된 `.app` 번들(권장: /Applications)에서만
///   안정적으로 반영된다 — `flutter run` 디버그 빌드에서는 무시될 수 있다.
class LaunchAtLoginService {
  const LaunchAtLoginService();

  static const MethodChannel _channel = MethodChannel(
    'app.haru/launch_at_login',
  );

  /// 현재 자동 실행 등록 여부. 미지원/실패 시 false.
  Future<bool> isEnabled() async {
    if (!AppPlatform.isDesktop) return false;
    try {
      final enabled = await _channel.invokeMethod<bool>('isEnabled');
      return enabled ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// 자동 실행을 [enabled] 로 설정하고 **실제 반영된 상태**를 반환한다.
  /// 네이티브가 실패를 알리면 [LaunchAtLoginException] 을 던진다(호출자가 안내 + 롤백).
  Future<bool> setEnabled(bool enabled) async {
    if (!AppPlatform.isDesktop) return false;
    try {
      final result = await _channel.invokeMethod<bool>('setEnabled', {
        'enabled': enabled,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      throw LaunchAtLoginException(e.message ?? '자동 실행 설정에 실패했어요.');
    } on MissingPluginException {
      throw const LaunchAtLoginException('이 플랫폼에서는 자동 실행을 지원하지 않아요.');
    }
  }
}

/// 자동 실행 설정 실패를 나타내는 예외 — 메시지는 사용자 노출용.
class LaunchAtLoginException implements Exception {
  const LaunchAtLoginException(this.message);

  final String message;

  @override
  String toString() => 'LaunchAtLoginException: $message';
}
