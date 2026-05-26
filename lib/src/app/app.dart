import 'package:flutter/material.dart';

import '../core/theme.dart';

/// 루트 [MaterialApp]. AppShell / 라우팅은 phase 4 에서 도입한다.
class SoloTodoApp extends StatelessWidget {
  const SoloTodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Solo Todo',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const _PlaceholderHome(),
    );
  }
}

class _PlaceholderHome extends StatelessWidget {
  const _PlaceholderHome();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Solo Todo', key: ValueKey('solo-todo-placeholder')),
      ),
    );
  }
}
