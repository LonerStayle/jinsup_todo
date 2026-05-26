import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/features/calendar/google_auth_service.dart';

void main() {
  test('OAuth client id 미설정 (test 환경) → service null + 비활성화', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(googleAuthServiceProvider), isNull);
    expect(container.read(googleCalendarAvailableProvider), isFalse);
  });
}
