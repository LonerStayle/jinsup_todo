import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/date_format.dart';
import '../../core/theme.dart';
import '../../domain/category.dart';

/// "빠른 추가" 입력 패널.
///
/// 책임은 입력 + 검증 + onSubmit 콜백까지. 실제 저장 (repo.upsert) 호출은 호출자
/// (phase 5 의 "추가 흐름" task) 가 담당한다.
///
/// UX 강조 (CLAUDE.md 비전): Calendar 등록은 토글 1 번이면 자동. Esc 로 취소, Enter 로 저장.
class AddTodoSheet extends StatefulWidget {
  const AddTodoSheet({
    super.key,
    this.initialCategory = Category.daily,
    required this.onSubmit,
    this.now,
  });

  final Category initialCategory;

  /// 테스트 결정성을 위해 주입 가능. 기본 [DateTime.now].
  final DateTime Function()? now;

  final void Function(AddTodoSubmission submission) onSubmit;

  /// modal bottom sheet 로 띄우는 헬퍼.
  static Future<void> show(
    BuildContext context, {
    Category initialCategory = Category.daily,
    required void Function(AddTodoSubmission) onSubmit,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: AddTodoSheet(
          initialCategory: initialCategory,
          onSubmit: onSubmit,
        ),
      ),
    );
  }

  @override
  State<AddTodoSheet> createState() => _AddTodoSheetState();
}

class _AddTodoSheetState extends State<AddTodoSheet> {
  late final TextEditingController _titleCtrl;
  late Category _category;
  DateTime? _dueAt;
  bool _addToCalendar = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _category = widget.initialCategory;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  bool get _canSubmit => _titleCtrl.text.trim().isNotEmpty;

  void _submit() {
    if (!_canSubmit) return;
    widget.onSubmit(
      AddTodoSubmission(
        title: _titleCtrl.text.trim(),
        category: _category,
        dueAt: _dueAt,
        addToCalendar: _dueAt != null && _addToCalendar,
      ),
    );
    Navigator.of(context).maybePop();
  }

  Future<void> _pickDueAt() async {
    final nowFn = widget.now ?? DateTime.now;
    final base = _dueAt ?? nowFn().add(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(nowFn().year - 1),
      lastDate: DateTime(nowFn().year + 3),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null || !mounted) return;
    setState(() {
      _dueAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _clearDueAt() {
    setState(() {
      _dueAt = null;
      _addToCalendar = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTokens.radiusL),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Shortcuts(
          shortcuts: <ShortcutActivator, Intent>{
            const SingleActivator(LogicalKeyboardKey.escape):
                const _DismissIntent(),
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              _DismissIntent: CallbackAction<_DismissIntent>(
                onInvoke: (_) {
                  Navigator.of(context).maybePop();
                  return null;
                },
              ),
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.space24,
                AppTokens.space16,
                AppTokens.space24,
                AppTokens.space24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Grabber(color: scheme.outline),
                  const SizedBox(height: AppTokens.space16),
                  Text(
                    '새 할 일',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppTokens.space16),
                  TextField(
                    key: const ValueKey('add-todo-title'),
                    controller: _titleCtrl,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    maxLength: 200,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                      hintText: '무엇을 할까요?',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: AppTokens.space16),
                  _SectionLabel(text: '카테고리'),
                  const SizedBox(height: AppTokens.space8),
                  _CategoryChips(
                    selected: _category,
                    onSelect: (c) => setState(() => _category = c),
                  ),
                  const SizedBox(height: AppTokens.space16),
                  _SectionLabel(text: '일정'),
                  const SizedBox(height: AppTokens.space8),
                  _DueRow(
                    dueAt: _dueAt,
                    onTap: _pickDueAt,
                    onClear: _clearDueAt,
                  ),
                  AnimatedSize(
                    duration: AppTokens.motionFast,
                    alignment: Alignment.topCenter,
                    child: _dueAt == null
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(
                              top: AppTokens.space12,
                            ),
                            child: _CalendarToggle(
                              value: _addToCalendar,
                              onChanged: (v) =>
                                  setState(() => _addToCalendar = v),
                            ),
                          ),
                  ),
                  const SizedBox(height: AppTokens.space20),
                  _Actions(canSubmit: _canSubmit, onSubmit: _submit),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DismissIntent extends Intent {
  const _DismissIntent();
}

class _Grabber extends StatelessWidget {
  const _Grabber({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppTokens.radiusFull),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.selected, required this.onSelect});

  final Category selected;
  final ValueChanged<Category> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppTokens.space8,
      runSpacing: AppTokens.space8,
      children: [
        for (final c in Category.values)
          _CategoryChip(
            category: c,
            selected: c == selected,
            onTap: () => onSelect(c),
          ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final Category category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = selected
        ? category.color.withValues(alpha: 0.18)
        : theme.colorScheme.surfaceContainerHighest;
    final fg = selected
        ? category.color
        : theme.colorScheme.onSurface.withValues(alpha: 0.78);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppTokens.radiusFull),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusFull),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.space12,
            vertical: AppTokens.space8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(category.icon, size: 16, color: fg),
              const SizedBox(width: AppTokens.space8),
              Text(
                category.label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: fg,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DueRow extends StatelessWidget {
  const _DueRow({
    required this.dueAt,
    required this.onTap,
    required this.onClear,
  });

  final DateTime? dueAt;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasDue = dueAt != null;
    final label = hasDue
        ? '${KoDate.pretty(dueAt!)} · ${KoDate.time(dueAt!)}'
        : '날짜·시간 없음 (지금 추가)';

    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppTokens.radiusM),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusM),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.space16,
            vertical: AppTokens.space12,
          ),
          child: Row(
            children: [
              Icon(
                Icons.event_outlined,
                size: 18,
                color: hasDue
                    ? scheme.primary
                    : scheme.onSurface.withValues(alpha: 0.55),
              ),
              const SizedBox(width: AppTokens.space12),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: hasDue
                        ? scheme.onSurface
                        : scheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ),
              if (hasDue)
                IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  tooltip: '일정 비우기',
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarToggle extends StatelessWidget {
  const _CalendarToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        Icon(
          Icons.calendar_month_outlined,
          size: 18,
          color: scheme.onSurface.withValues(alpha: 0.78),
        ),
        const SizedBox(width: AppTokens.space12),
        Expanded(
          child: Text(
            'Google Calendar 에 등록',
            style: theme.textTheme.bodyMedium,
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.canSubmit, required this.onSubmit});

  final bool canSubmit;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).maybePop(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: AppTokens.space12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTokens.radiusM),
              ),
            ),
            child: const Text('취소'),
          ),
        ),
        const SizedBox(width: AppTokens.space12),
        Expanded(
          child: FilledButton(
            onPressed: canSubmit ? onSubmit : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: AppTokens.space12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTokens.radiusM),
              ),
            ),
            child: const Text('추가'),
          ),
        ),
      ],
    );
  }
}

/// AddTodoSheet 가 사용자가 제출한 form 데이터를 한 묶음으로 전달.
class AddTodoSubmission {
  const AddTodoSubmission({
    required this.title,
    required this.category,
    required this.dueAt,
    required this.addToCalendar,
  });

  final String title;
  final Category category;
  final DateTime? dueAt;
  final bool addToCalendar;
}
