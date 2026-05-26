import 'dart:io' show Platform;

/// Solo Todo 가 지원하는 두 폼팩터.
///
/// 비전상 macOS desktop + Android phone 만 지원하므로 둘 외 플랫폼이 와도
/// [mobile] 로 fallback (현재 환경에선 발생하지 않음).
enum FormFactor { desktop, mobile }

/// 런타임 플랫폼 분기 헬퍼.
///
/// 위젯 트리는 가급적 `if (AppPlatform.isDesktop)` 한 줄로만 분기하고,
/// 두 구현체를 각각 stateless 위젯으로 분리해 유지·관리한다.
class AppPlatform {
  const AppPlatform._();

  static FormFactor get formFactor =>
      Platform.isMacOS ? FormFactor.desktop : FormFactor.mobile;

  static bool get isDesktop => formFactor == FormFactor.desktop;
  static bool get isMobile => formFactor == FormFactor.mobile;
}
