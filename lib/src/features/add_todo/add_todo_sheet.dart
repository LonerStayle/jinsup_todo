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
    this.initialDueAt,
    this.initialAllDay = true,
  });

  final Category initialCategory;

  /// 테스트 결정성을 위해 주입 가능. 기본 [DateTime.now].
  final DateTime Function()? now;

  /// 초기 dueAt 값. 위젯 테스트에서 picker dialog 우회용. null 이면 일정 없음.
  @visibleForTesting
  final DateTime? initialDueAt;

  /// [initialDueAt] 가 종일 의미인지. 기본 true.
  @visibleForTesting
  final bool initialAllDay;

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

  /// dueAt 의 시간 지정 여부. true = 하루 종일 (시간 부분 의미 없음, 00:00 보관).
  /// false = 시간이 의미 있는 todo (`_dueAt` 의 시각 그대로).
  bool _allDay = true;
  bool _addToCalendar = false;

  /// 더블 submit race 가드. _submit 이 한 번이라도 호출되면 true 로 set 되어 후속
  /// tap / Enter 가 추가 onSubmit 콜백 호출을 못 하게 막는다. Navigator.maybePop 이
  /// 동기적으로 처리되지만 그 직전 frame 에 두 번째 tap 이 들어와 두 todo 가 생성되던
  /// 경우 방지.
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _category = widget.initialCategory;
    _dueAt = widget.initialDueAt;
    _allDay = widget.initialAllDay;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  bool get _canSubmit => !_submitted && _titleCtrl.text.trim().isNotEmpty;

  void _submit() {
    if (_submitted || _titleCtrl.text.trim().isEmpty) return;
    _submitted = true;
    widget.onSubmit(
      AddTodoSubmission(
        title: _titleCtrl.text.trim(),
        category: _category,
        dueAt: _dueAt,
        isAllDay: _dueAt != null && _allDay,
        addToCalendar: _dueAt != null && _addToCalendar,
      ),
    );
    Navigator.of(context).maybePop();
  }

  /// 날짜만 받는다 — 시간 picker 는 강제하지 않고, 기본은 "하루 종일".
  /// 사용자가 시간이 필요하면 [_pickTime] 액션 또는 [_DueRow] 의 시간 칩으로 추가.
  Future<void> _pickDueDate() async {
    final nowFn = widget.now ?? DateTime.now;
    final base = _dueAt ?? nowFn();
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(nowFn().year - 1),
      lastDate: DateTime(nowFn().year + 3),
    );
    if (date == null || !mounted) return;
    setState(() {
      // 시간을 이미 지정해 둔 채로 날짜만 다시 고르는 경우 → 시간 보존.
      if (_dueAt != null && !_allDay) {
        _dueAt = DateTime(
          date.year,
          date.month,
          date.day,
          _dueAt!.hour,
          _dueAt!.minute,
        );
      } else {
        _dueAt = DateTime(date.year, date.month, date.day);
        _allDay = true;
      }
    });
  }

  Future<void> _pickTime() async {
    final base = _dueAt ?? (widget.now ?? DateTime.now)();
    final initial = _allDay
        ? const TimeOfDay(hour: 9, minute: 0)
        : TimeOfDay.fromDateTime(base);
    final time = await showTimePicker(context: context, initialTime: initial);
    if (time == null || !mounted) return;
    setState(() {
      final d = _dueAt ?? base;
      _dueAt = DateTime(d.year, d.month, d.day, time.hour, time.minute);
      _allDay = false;
    });
  }

  void _makeAllDay() {
    final d = _dueAt;
    if (d == null) return;
    setState(() {
      _dueAt = DateTime(d.year, d.month, d.day);
      _allDay = true;
    });
  }

  void _clearDueAt() {
    setState(() {
      _dueAt = null;
      _allDay = true;
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
                    allDay: _allDay,
                    onPickDate: _pickDueDate,
                    onPickTime: _pickTime,
                    onMakeAllDay: _makeAllDay,
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
    required this.allDay,
    required this.onPickDate,
    required this.onPickTime,
    required this.onMakeAllDay,
    required this.onClear,
  });

  final DateTime? dueAt;
  final bool allDay;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;
  final VoidCallback onMakeAllDay;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasDue = dueAt != null;
    final label = !hasDue
        ? '날짜 추가 (선택)'
        : (allDay
              ? '${KoDate.pretty(dueAt!)} · 하루 종일'
              : '${KoDate.pretty(dueAt!)} · ${KoDate.time(dueAt!)}');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppTokens.radiusM),
          child: InkWell(
            onTap: onPickDate,
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
        ),
        if (hasDue) ...[
          const SizedBox(height: AppTokens.space8),
          Row(
            children: [
              if (allDay)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPickTime,
                    icon: const Icon(Icons.schedule_outlined, size: 16),
                    label: const Text('시간 추가'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTokens.space8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTokens.radiusM),
                      ),
                    ),
                  ),
                )
              else ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPickTime,
                    icon: const Icon(Icons.schedule_outlined, size: 16),
                    label: const Text('시간 변경'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTokens.space8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTokens.radiusM),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppTokens.space8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onMakeAllDay,
                    icon: const Icon(Icons.wb_sunny_outlined, size: 16),
                    label: const Text('하루 종일'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTokens.space8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTokens.radiusM),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
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
    this.isAllDay = false,
    required this.addToCalendar,
  });

  final String title;
  final Category category;
  final DateTime? dueAt;

  /// dueAt 이 "하루 종일" 의미인지. dueAt 이 null 이면 의미 없음 (false).
  /// AddTodoController 가 CalendarService.createEventForTodo 에 전달.
  final bool isAllDay;

  final bool addToCalendar;
}
