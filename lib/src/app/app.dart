import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../ui/app_shell.dart';

/// 루트 위젯. 단일 [MaterialApp] 베이스 — 폼팩터 분기는 [AppShell] 내부에서 처리.
///
/// macos_ui 의 본격 적용 (window chrome, native widgets) 은 phase 6 의
/// "macOS 전용" task 들에서 도입한다.
class SoloTodoApp extends StatelessWidget {
  const SoloTodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Solo Todo',
      theme: AppTheme.mobileLight(),
      darkTheme: AppTheme.mobileDark(),
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: const AppShell(),
    );
  }
}
