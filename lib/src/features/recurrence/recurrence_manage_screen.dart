import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date_format.dart';
import '../../core/theme.dart';
import '../../domain/recurrence.dart';
import '../../domain/todo.dart';
import '../../ui/widgets/empty_state.dart';
import '../home/today_providers.dart';
import '../todo_actions/todo_actions_controller.dart';

/// date-repeat (FR-6) — 반복 규칙 관리 화면.
///
/// 반복 마스터는 [VisibilityPolicy] 로 일반 목록에서 숨겨지므로, 규칙을 보고 "반복 중지"
/// 하는 유일한 진입점이다. "반복 중지" 는 마스터만 삭제 → 미래 발생분 생성이 멈추고,
/// 이미 만들어진 인스턴스(과거/오늘 항목)는 일반 할 일로 남는다(비파괴적).
class RecurrenceManageScreen extends ConsumerWidget {
  const RecurrenceManageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final masters = ref.watch(recurringMastersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('반복 관리')),
      body: masters.isEmpty
          ? const EmptyState(
              icon: Icons.repeat_rounded,
              title: '반복 중인 할 일이 없어요',
              subtitle: '할 일을 추가할 때 날짜와 함께 반복 주기를 정하면 여기에 모여요.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(AppTokens.space16),
              itemCount: masters.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppTokens.space8),
              itemBuilder: (context, i) => _MasterCard(
                master: masters[i],
                onStop: () => _confirmStop(context, ref, masters[i]),
              ),
            ),
    );
  }

  Future<void> _confirmStop(
    BuildContext context,
    WidgetRef ref,
    Todo master,
  ) async {
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
    }
  }
}

class _MasterCard extends StatelessWidget {
  const _MasterCard({required this.master, required this.onStop});

  final Todo master;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rule = master.recurrence;
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
                color: master.category.color,
                borderRadius: BorderRadius.circular(AppTokens.radiusS),
              ),
            ),
            const SizedBox(width: AppTokens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.repeat_rounded,
                        size: 16,
                        color: master.category.color,
                      ),
                      const SizedBox(width: AppTokens.space4),
                      Flexible(
                        child: Text(
                          master.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTokens.space2),
                  Text(
                    rule == null
                        ? '반복'
                        : describeRecurrence(rule, master.recurrenceEndAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              key: ValueKey('recur-stop-${master.id}'),
              onPressed: onStop,
              style: TextButton.styleFrom(foregroundColor: scheme.error),
              child: const Text('반복 중지'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 반복 규칙을 한국어 한 줄로 요약. 예: "2주마다 (월·수) · 2026.12.31 까지".
String describeRecurrence(RecurrenceRule rule, DateTime? endAt) {
  const unit = {
    RecurrenceFreq.daily: '일',
    RecurrenceFreq.weekly: '주',
    RecurrenceFreq.monthly: '개월',
    RecurrenceFreq.yearly: '년',
  };
  const weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

  final n = rule.interval;
  final base = n == 1 ? '매${unit[rule.freq]}' : '$n${unit[rule.freq]}마다';

  final parts = <String>[base];
  if (rule.freq == RecurrenceFreq.weekly && rule.byWeekday.isNotEmpty) {
    final days = (rule.byWeekday.toList()..sort())
        .map((wd) => weekdayLabels[wd - 1])
        .join('·');
    parts.add('($days)');
  }
  var summary = parts.join(' ');
  if (endAt != null) summary = '$summary · ${KoDate.shortDate(endAt)} 까지';
  return summary;
}
