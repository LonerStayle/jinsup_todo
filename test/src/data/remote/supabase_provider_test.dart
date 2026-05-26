import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:solo_todo/src/data/remote/supabase_provider.dart';

void main() {
  test('env 미설정 (test 환경 default) → supabaseClientProvider == null', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(supabaseClientProvider), isNull);
    expect(container.read(supabaseEnabledProvider), isFalse);
  });

  test('initSupabaseFromEnv: env 미설정이면 false 반환 + throw 없음', () async {
    final ok = await initSupabaseFromEnv();
    expect(ok, isFalse);
  });
}
