import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';

import '../core/platform.dart';
import '../core/theme.dart';

/// 루트 위젯. 폼팩터에 따라 macos_ui 의 [MacosApp] 또는 Material [MaterialApp] 으로
/// 분기한다. AppShell / 라우팅은 phase 4 에서 도입.
class SoloTodoApp extends StatelessWidget {
  const SoloTodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPlatform.isDesktop ? const _DesktopApp() : const _MobileApp();
  }
}

class _DesktopApp extends StatelessWidget {
  const _DesktopApp();

  @override
  Widget build(BuildContext context) {
    return MacosApp(
      title: 'Solo Todo',
      theme: AppTheme.desktopLight(),
      darkTheme: AppTheme.desktopDark(),
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: const _PlaceholderHome(),
    );
  }
}

class _MobileApp extends StatelessWidget {
  const _MobileApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Solo Todo',
      theme: AppTheme.mobileLight(),
      darkTheme: AppTheme.mobileDark(),
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: const _PlaceholderHome(),
    );
  }
}

class _PlaceholderHome extends StatelessWidget {
  const _PlaceholderHome();

  @override
  Widget build(BuildContext context) {
    // 둘 다 Material 위젯 (Scaffold / Text) 으로 렌더 — phase 4 에서 AppShell 도입 시
    // MacosScaffold / macOS 사이드바 등으로 본격 분기.
    return const Scaffold(
      body: Center(
        child: Text('Solo Todo', key: ValueKey('solo-todo-placeholder')),
      ),
    );
  }
}
