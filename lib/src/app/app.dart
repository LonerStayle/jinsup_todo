import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../data/remote/supabase_provider.dart';
import '../features/auth/auth_providers.dart';
import '../features/auth/sign_in_screen.dart';
import '../ui/app_shell.dart';

/// 루트 위젯. 단일 [MaterialApp] 베이스 — 폼팩터 분기는 [AppShell] 내부에서 처리.
class SoloTodoApp extends StatelessWidget {
  const SoloTodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '하루',
      theme: AppTheme.mobileLight(),
      darkTheme: AppTheme.mobileDark(),
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: const _AuthGate(),
    );
  }
}

/// Supabase 가 enabled 일 때만 SignInScreen 분기를 적용. local-only 모드에서는 곧장 AppShell.
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supabaseEnabled = ref.watch(supabaseEnabledProvider);
    if (!supabaseEnabled) return const AppShell();

    final user = ref.watch(currentUserProvider);
    return user == null ? const SignInScreen() : const AppShell();
  }
}
