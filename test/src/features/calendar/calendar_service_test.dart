import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/features/calendar/calendar_service.dart';

void main() {
  test('GoogleAuthService 미설정 → calendarServiceProvider == null', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(calendarServiceProvider), isNull);
  });
}
