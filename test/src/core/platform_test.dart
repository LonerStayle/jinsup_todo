import 'dart:io' show Platform;

import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/core/platform.dart';

void main() {
  test('AppPlatform.formFactor 는 host OS 와 일치한다', () {
    // 호스트가 macOS 면 desktop, 그 외 (Android/Linux 등) 는 mobile 로 분류.
    final expected = Platform.isMacOS ? FormFactor.desktop : FormFactor.mobile;
    expect(AppPlatform.formFactor, expected);
    expect(AppPlatform.isDesktop, expected == FormFactor.desktop);
    expect(AppPlatform.isMobile, expected == FormFactor.mobile);
  });

  test('isDesktop 과 isMobile 은 상호 배타적', () {
    expect(AppPlatform.isDesktop, isNot(AppPlatform.isMobile));
  });
}
