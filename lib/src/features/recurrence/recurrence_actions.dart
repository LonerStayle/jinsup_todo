import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/recurrence_materializer.dart';
import '../../domain/todo.dart';
import '../outline/tree_providers.dart';
import '../todo_actions/todo_actions_controller.dart';

/// 반복 항목(인스턴스 또는 마스터)에서 그 시리즈의 반복을 중지한다 — confirm 후 마스터
/// 삭제(비파괴적). 미래 발생분 생성이 멈추고, 이미 만들어진 항목은 일반 할 일로 남는다.
///
/// 반환: 실제로 중지했으면 true (취소/마스터 없음이면 false). 호출자는 true 일 때
/// 화면 정리(예: 편집 시트 닫기)를 할 수 있다.
Future<bool> confirmStopRecurrence(
  BuildContext context,
  WidgetRef ref,
  Todo item,
) async {
  final all = ref.read(allTodosProvider).asData?.value ?? const <Todo>[];
  final master = RecurrenceMaterializer.findMaster(all, item);
  if (master == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('반복 정보를 찾을 수 없어요.')));
    }
    return false;
  }
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('반복 중지'),
      content: Text(
        '"${master.title}" 의 반복을 멈출까요?\n'
        '앞으로 새 항목은 생기지 않아요. 이미 만들어진 항목은 그대로 남아요.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('반복 중지'),
        ),
      ],
    ),
  );
  if (ok == true) {
    await ref.read(todoActionsProvider).delete(master);
    return true;
  }
  return false;
}
