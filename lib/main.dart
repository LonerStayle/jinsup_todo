import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app/app.dart';
import 'src/app/env.dart';
import 'src/core/perf.dart';
import 'src/data/remote/supabase_provider.dart';

Future<void> main() async {
  // 콜드 스타트 stopwatch 시작 — 첫 lazy 접근이 init 트리거. ensureInitialized 보다 먼저.
  ColdStartProbe.instance;

  WidgetsFlutterBinding.ensureInitialized();

  final envDiag = Env.diagnostics();
  if (envDiag != null) {
    debugPrint('[solo_todo] $envDiag');
  }

  await initSupabaseFromEnv();

  runApp(const ProviderScope(child: SoloTodoApp()));

  // 첫 frame 렌더 완료 시점에 cold start 측정 마감 + 60fps 감시 시작.
  scheduleColdStartCapture();
  FpsMonitor.instance.start();
}
