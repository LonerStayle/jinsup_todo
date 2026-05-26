import 'package:flutter/material.dart';

import '../core/platform.dart';
import '../core/theme.dart';
import 'destination.dart';

/// 폼팩터별 분기 컨테이너.
///
/// - macOS desktop: 좌측 사이드바 (220 px) + 우측 메인 영역
/// - Android phone: 메인 영역 + 하단 [NavigationBar] (6 destination)
///
/// destination 선택 state 만 보유. 본격 화면 (HomeScreen / CategoryView) 은
/// phase 4 의 다음 task 들에서 main area 자리에 들어간다.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  void _select(int i) {
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final destination = AppDestination.all[_index];

    if (AppPlatform.isDesktop) {
      return Scaffold(
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
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: destination.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTokens.radiusL),
            ),
            child: Icon(destination.icon, size: 36, color: destination.color),
          ),
          const SizedBox(height: AppTokens.space20),
          Text(destination.label, style: theme.textTheme.headlineMedium),
          const SizedBox(height: AppTokens.space8),
          Text(
            destination.isToday
                ? '오늘의 할 일 화면은 다음 task 에서 채워집니다.'
                : '${destination.label} 카테고리 보기는 다음 task 에서 채워집니다.',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
