import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// 가벼운 단일 박스 skeleton. 별도 shimmer 패키지 의존성 없이 [Opacity] pulse 로 표현.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.radius = AppTokens.radiusS,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// [TodoTile] 자리에 동일한 높이로 들어가는 skeleton placeholder.
class TodoTileSkeleton extends StatelessWidget {
  const TodoTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space16,
          vertical: AppTokens.space12,
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 36,
              decoration: BoxDecoration(
                color: scheme.onSurface.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppTokens.radiusS),
              ),
            ),
            const SizedBox(width: AppTokens.space12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 160, height: 16),
                  SizedBox(height: AppTokens.space8),
                  SkeletonBox(width: 64, height: 12),
                ],
              ),
            ),
            const SizedBox(width: AppTokens.space12),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: scheme.onSurface.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// [itemCount] 개의 [TodoTileSkeleton] 을 부드러운 pulse 로 묶어 보여준다.
class TodoListSkeleton extends StatefulWidget {
  const TodoListSkeleton({super.key, this.itemCount = 4});

  final int itemCount;

  @override
  State<TodoListSkeleton> createState() => _TodoListSkeletonState();
}

class _TodoListSkeletonState extends State<TodoListSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.space24),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) =>
            Opacity(opacity: 0.6 + 0.4 * _ctrl.value, child: child),
        child: Column(
          children: [
            for (var i = 0; i < widget.itemCount; i++) ...[
              const TodoTileSkeleton(),
              const SizedBox(height: AppTokens.space8),
            ],
          ],
        ),
      ),
    );
  }
}
