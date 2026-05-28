import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../domain/todo.dart';
import 'dismissible_todo_tile.dart';

/// 오늘 화면 todo list — 체크 토글로 순서가 바뀌거나 추가/삭제될 때 SliverAnimatedList 의
/// SizeTransition + FadeTransition 으로 부드럽게 reorder 한다.
///
/// 외부에서는 평범한 [List<Todo>] 를 넘기면, 내부에서 id 기반 diff 로 insert/remove 를
/// SliverAnimatedList 의 상태에 직접 발화. 1인 사용자 todo 평균 길이 (~수십 건) 기준
/// 단순 O(n·m) 비교로 충분.
class AnimatedTodoSliver extends StatefulWidget {
  const AnimatedTodoSliver({
    super.key,
    required this.todos,
    required this.onToggle,
    required this.onDelete,
    this.onTap,
    this.breadcrumbBuilder,
  });

  final List<Todo> todos;
  final void Function(Todo) onToggle;
  final void Function(Todo) onDelete;

  /// v1.2 — tile tap → 호출자가 edit sheet 진입 등. null 이면 tap 무동작.
  final void Function(Todo)? onTap;

  /// 각 todo 위에 표시할 breadcrumb 텍스트 (예: "JS슈퍼 / 울트라 모드"). null 반환 시
  /// breadcrumb 없음. v1.1 today list 에서 트리 path 시각용.
  final String? Function(Todo)? breadcrumbBuilder;

  @override
  State<AnimatedTodoSliver> createState() => _AnimatedTodoSliverState();
}

class _AnimatedTodoSliverState extends State<AnimatedTodoSliver> {
  final GlobalKey<SliverAnimatedListState> _listKey =
      GlobalKey<SliverAnimatedListState>();

  /// SliverAnimatedList 에 실제로 보여지고 있는 현재 model.
  /// widget.todos 의 변화에 맞춰 diff 로 갱신한다 (remove/insert).
  late List<Todo> _displayed;

  @override
  void initState() {
    super.initState();
    _displayed = List<Todo>.of(widget.todos);
  }

  @override
  void didUpdateWidget(covariant AnimatedTodoSliver old) {
    super.didUpdateWidget(old);
    _syncWith(widget.todos);
  }

  void _syncWith(List<Todo> next) {
    final state = _listKey.currentState;
    if (state == null) {
      // SliverAnimatedList 가 아직 mount 안 된 상태 (테스트의 첫 frame 등). 즉시 교체.
      _displayed = List<Todo>.of(next);
      return;
    }

    // 1) 삭제 — 새 list 에 없는 id 를 역순 (큰 index 부터) 으로 제거.
    final nextIds = next.map((t) => t.id).toSet();
    for (int i = _displayed.length - 1; i >= 0; i--) {
      if (!nextIds.contains(_displayed[i].id)) {
        final removed = _displayed.removeAt(i);
        state.removeItem(
          i,
          (ctx, anim) => _buildAnimated(ctx, removed, anim),
          duration: AppTokens.motionMid,
        );
      }
    }

    // 2) 위치 보정 + 추가 — 새 list 의 순서대로 walk.
    for (int newIndex = 0; newIndex < next.length; newIndex++) {
      final id = next[newIndex].id;
      final oldIndex = _indexOfId(_displayed, id);

      if (oldIndex < 0) {
        // 신규 추가.
        _displayed.insert(newIndex, next[newIndex]);
        state.insertItem(newIndex, duration: AppTokens.motionMid);
      } else if (oldIndex != newIndex) {
        // 위치 이동 — remove + insert 로 표현 (체크 토글 시의 핵심 케이스).
        final moved = _displayed.removeAt(oldIndex);
        state.removeItem(
          oldIndex,
          (ctx, anim) => _buildAnimated(ctx, moved, anim),
          duration: AppTokens.motionMid,
        );
        _displayed.insert(newIndex, next[newIndex]);
        state.insertItem(newIndex, duration: AppTokens.motionMid);
      } else {
        // 같은 위치 — 내용만 갱신 (title/doneAt 등). DismissibleTodoTile 가 새 todo 로
        // 자동 rebuild 되어 in-place 반영. 별도 애니메이션 X.
        _displayed[newIndex] = next[newIndex];
      }
    }
  }

  static int _indexOfId(List<Todo> list, String id) {
    for (int i = 0; i < list.length; i++) {
      if (list[i].id == id) return i;
    }
    return -1;
  }

  Widget _buildAnimated(BuildContext context, Todo todo, Animation<double> a) {
    return FadeTransition(
      opacity: a,
      child: SizeTransition(
        sizeFactor: a,
        axisAlignment: -1,
        child: _PaddedTile(
          todo: todo,
          breadcrumb: widget.breadcrumbBuilder?.call(todo),
          onToggle: () => widget.onToggle(todo),
          onDelete: () => widget.onDelete(todo),
          onTap: widget.onTap == null ? null : () => widget.onTap!(todo),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SliverAnimatedList(
      key: _listKey,
      initialItemCount: _displayed.length,
      itemBuilder: (ctx, i, anim) {
        // index 가 transient 한 remove/insert 도중 _displayed 범위를 벗어날 수 있다.
        // (SliverAnimatedList 가 removeItem 의 builder 를 elapse 후에도 호출)
        if (i >= _displayed.length) {
          return const SizedBox.shrink();
        }
        return _buildAnimated(ctx, _displayed[i], anim);
      },
    );
  }
}

/// 각 tile 의 하단 spacing 을 통일 — 이전 [SliverList.separated] 대체.
/// breadcrumb 가 있으면 tile 위에 작은 caption 으로 트리 path 표시.
class _PaddedTile extends StatelessWidget {
  const _PaddedTile({
    required this.todo,
    required this.onToggle,
    required this.onDelete,
    this.onTap,
    this.breadcrumb,
  });

  final Todo todo;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback? onTap;
  final String? breadcrumb;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.space8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (breadcrumb != null && breadcrumb!.isNotEmpty)
            Padding(
              key: const ValueKey('todo-breadcrumb'),
              padding: const EdgeInsets.only(
                left: AppTokens.space16,
                right: AppTokens.space16,
                bottom: AppTokens.space2,
              ),
              child: Text(
                breadcrumb!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          DismissibleTodoTile(
            todo: todo,
            onToggle: onToggle,
            onDelete: onDelete,
            onTap: onTap,
          ),
        ],
      ),
    );
  }
}
