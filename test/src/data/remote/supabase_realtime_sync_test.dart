import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/data/remote/supabase_realtime_sync.dart';

void main() {
  test('Supabase 미설정 → supabaseRealtimeSyncProvider == null (활성화 안 됨)', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(supabaseRealtimeSyncProvider), isNull);
  });
}
