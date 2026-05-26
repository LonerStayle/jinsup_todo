import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app/app.dart';
import 'src/app/env.dart';
import 'src/data/remote/supabase_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final envDiag = Env.diagnostics();
  if (envDiag != null) {
    debugPrint('[solo_todo] $envDiag');
  }

  await initSupabaseFromEnv();

  runApp(const ProviderScope(child: SoloTodoApp()));
}
