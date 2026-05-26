import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/platform.dart';
import '../core/theme.dart';
import '../domain/category.dart';
import '../features/add_todo/add_todo_controller.dart';
import '../features/add_todo/add_todo_sheet.dart';
import '../features/category/category_view.dart';
import '../features/home/home_screen.dart';
import 'destination.dart';

/// 폼팩터 분기 컨테이너 + FAB (빠른 추가 트리거).
///
/// - macOS desktop: 좌측 사이드바 + 우측 메인 + FAB (Cmd+N 단축키는 phase 6 에서 연결)
/// - Android phone: 메인 + 하단 NavigationBar + FAB
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  void _select(int i) {
    setState(() => _index = i);
  }

  Future<void> _openAddTodo() async {
    final dest = AppDestination.all[_index];
    final initialCategory = dest.category ?? Category.daily;
    await AddTodoSheet.show(
      context,
      initialCategory: initialCategory,
      onSubmit: (submission) {
        ref.read(addTodoControllerProvider).add(submission);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final destination = AppDestination.all[_index];

    final fab = FloatingActionButton.extended(
      key: const ValueKey('add-todo-fab'),
      onPressed: _openAddTodo,
      icon: const Icon(Icons.add),
      label: const Text('추가'),
      tooltip: '새 할 일 (Cmd+N)',
    );

    if (AppPlatform.isDesktop) {
      return Scaffold(
        floatingActionButton: fab,
        body: Row(
          children: [
            _Sidebar(selectedIndex: _index, onSelect: _select),
            const VerticalDivider(width: AppTokens.hairline),
            Expanded(child: _MainArea(destination: destination)),
          ],
        ),
      );
    }

    return Scaffold(
      floatingActionButton: fab,
      body: SafeArea(child: _MainArea(destination: destination)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: [
          for (final d in AppDestination.all)
            NavigationDestination(icon: Icon(d.icon), label: d.label),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.selectedIndex, required this.onSelect});

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      width: 220,
      child: ColoredBox(
        color: colorScheme.surfaceContainerHighest,
        child: SafeArea(
          right: false,
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: AppTokens.space12),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTokens.space20,
                  AppTokens.space8,
                  AppTokens.space20,
                  AppTokens.space16,
                ),
                child: Text(
                  'Solo Todo',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              for (var i = 0; i < AppDestination.all.length; i++)
                _SidebarItem(
                  destination: AppDestination.all[i],
                  selected: i == selectedIndex,
                  onTap: () => onSelect(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final AppDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = selected
        ? scheme.onSurface
        : scheme.onSurface.withValues(alpha: 0.78);
    final bg = selected
        ? scheme.primary.withValues(alpha: 0.12)
        : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space8,
        vertical: AppTokens.space2,
      ),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(AppTokens.radiusM),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.space12,
              vertical: AppTokens.space8,
            ),
            child: Row(
              children: [
                Icon(destination.icon, size: 18, color: destination.color),
                const SizedBox(width: AppTokens.space12),
                Expanded(
                  child: Text(
                    destination.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: fg,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MainArea extends StatelessWidget {
  const _MainArea({required this.destination});

  final AppDestination destination;

  @override
  Widget build(BuildContext context) {
    if (destination.isToday) return const HomeScreen();
    return CategoryView(category: destination.category!);
  }
}
