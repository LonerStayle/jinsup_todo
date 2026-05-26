import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app/app.dart';
import 'src/app/env.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final envDiag = Env.diagnostics();
  if (envDiag != null) {
    // env 가 비어 있어도 placeholder 단계까지는 동작한다.
    // Supabase / Calendar 가 필요한 task 단계에서 다시 가드한다.
    debugPrint('[solo_todo] $envDiag');
  }

  runApp(const ProviderScope(child: SoloTodoApp()));
}
