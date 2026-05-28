import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/date_format.dart';
import '../../core/theme.dart';
import '../../domain/category.dart';
import '../../domain/todo.dart' show Todo, TodoType;

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
    this.onUpdate,
    this.initialTodo,
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

  /// 신규 추가 모드 — submission 콜백. edit 모드 (initialTodo != null) 면 호출 안 됨.
  final void Function(AddTodoSubmission submission) onSubmit;

  /// v1.2 — edit 모드 콜백. [initialTodo] 가 non-null 일 때 _submit 이 update 분기로
  /// 호출. 호출자는 todoActionsProvider.update 또는 동등 mutation 수행.
  final void Function(Todo updated)? onUpdate;

  /// v1.2 — null 이면 add 모드 (기존), non-null 이면 edit 모드. _titleCtrl /
  /// _descriptionCtrl / _category / _dueAt / _type 가 모두 prefill 된다.
  final Todo? initialTodo;

  /// 멀티라인 paste 시 줄바꿈으로 split + 빈 줄 제거 → 의미 있는 줄.
  /// 단위 테스트가 직접 호출하기 위해 public static 으로 노출.
  @visibleForTesting
  static List<String> splitBulkLines(String raw) =>
      raw.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

  /// modal bottom sheet 로 띄우는 헬퍼.
  ///
  /// add 모드: [initialTodo] null + [onSubmit] 만. edit 모드: [initialTodo] non-null
  /// + [onUpdate] 콜백 — 호출자가 todoActionsProvider.update 호출.
  static Future<void> show(
    BuildContext context, {
    Category initialCategory = Category.daily,
    required void Function(AddTodoSubmission) onSubmit,
    void Function(Todo updated)? onUpdate,
    Todo? initialTodo,
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
          onUpdate: onUpdate,
          initialTodo: initialTodo,
        ),
      ),
    );
  }

  @override
  State<AddTodoSheet> createState() => _AddTodoSheetState();
}

class _AddTodoSheetState extends State<AddTodoSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descriptionCtrl;
  late Category _category;
  DateTime? _dueAt;

  /// dueAt 의 시간 지정 여부. true = 하루 종일 (시간 부분 의미 없음, 00:00 보관).
  /// false = 시간이 의미 있는 todo (`_dueAt` 의 시각 그대로).
  bool _allDay = true;
  bool _addToCalendar = false;

  /// v1.1 — 추가할 항목의 종류. note 면 일정/캘린더 영역은 비활성 (의미 없음).
  TodoType _type = TodoType.task;

  /// v1.2 — 상세 메모 펼침/접힘. default 접힘. description 가 비어있지 않으면 펼침.
  bool _showDescription = false;

  /// edit 모드 (initialTodo != null) 여부 — 시그니처 / 버튼 라벨 / submit 분기 사용.
  bool get _isEditMode => widget.initialTodo != null;

  /// 더블 submit race 가드. _submit 이 한 번이라도 호출되면 true 로 set 되어 후속
  /// tap / Enter 가 추가 onSubmit 콜백 호출을 못 하게 막는다.
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialTodo;
    _titleCtrl = TextEditingController(text: initial?.title ?? '');
    _descriptionCtrl = TextEditingController(text: initial?.description ?? '');
    _category = initial?.category ?? widget.initialCategory;
    _dueAt = initial?.dueAt ?? widget.initialDueAt;
    _allDay = widget.initialAllDay;
    _type = initial?.type ?? TodoType.task;
    // edit 모드에서 description 이 비어있지 않으면 펼친 상태로 시작.
    _showDescription = (initial?.description ?? '').isNotEmpty;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  bool get _canSubmit => !_submitted && _titleCtrl.text.trim().isNotEmpty;

  void _submit() {
    if (_submitted || _titleCtrl.text.trim().isEmpty) return;
    _submitted = true;
    final isNote = _type == TodoType.note;
    final trimmedDesc = _descriptionCtrl.text.trim();
    final descOrNull = trimmedDesc.isEmpty ? null : trimmedDesc;

    // edit 모드 — onUpdate 콜백 호출 (updatedAt 갱신은 호출자/Controller 책임).
    final initial = widget.initialTodo;
    if (_isEditMode && initial != null) {
      final updated = initial.copyWith(
        title: _titleCtrl.text.trim(),
        category: _category,
        dueAt: isNote ? null : _dueAt,
        type: _type,
        description: descOrNull,
      );
      widget.onUpdate?.call(updated);
      Navigator.of(context).maybePop();
      return;
    }

    // add 모드 — 기존 흐름. note 는 일정/캘린더 모두 강제 null/false.
    widget.onSubmit(
      AddTodoSubmission(
        title: _titleCtrl.text.trim(),
        category: _category,
        dueAt: isNote ? null : _dueAt,
        isAllDay: !isNote && _dueAt != null && _allDay,
        addToCalendar: !isNote && _dueAt != null && _addToCalendar,
        type: _type,
        description: descOrNull,
      ),
    );
    Navigator.of(context).maybePop();
  }

  /// 같은 카테고리 / parent / dueAt / type 으로 N건 일괄 추가. _submitted race 가드.
  /// v1.1 첫 cut — 평탄 (들여쓰기 인식 X). 들여쓰기 자동 트리화는 v1.2.
  void _submitBulk(List<String> titles) {
    if (_submitted || titles.isEmpty) return;
    _submitted = true;
    final isNote = _type == TodoType.note;
    final trimmedDesc = _descriptionCtrl.text.trim();
    final descOrNull = trimmedDesc.isEmpty ? null : trimmedDesc;
    for (final t in titles) {
      widget.onSubmit(
        AddTodoSubmission(
          title: t,
          category: _category,
          dueAt: isNote ? null : _dueAt,
          isAllDay: !isNote && _dueAt != null && _allDay,
          addToCalendar: !isNote && _dueAt != null && _addToCalendar,
          type: _type,
          description: descOrNull,
        ),
      );
    }
    if (mounted) Navigator.of(context).maybePop();
  }

  /// TextField onChanged 콜백. 멀티라인 paste 면 confirm dialog → bulk submit.
  /// 단일 라인 입력은 일반 setState 만 (추가 버튼 활성화 토글).
  Future<void> _onTitleChanged(String value) async {
    if (!value.contains('\n')) {
      setState(() {});
      return;
    }
    final lines = AddTodoSheet.splitBulkLines(value);
    if (lines.length < 2) {
      // 빈 줄 + 단일 줄 케이스 — \n 제거 후 단일 todo 흐름 유지.
      _titleCtrl.text = lines.isEmpty ? '' : lines.first;
      _titleCtrl.selection = TextSelection.collapsed(
        offset: _titleCtrl.text.length,
      );
      setState(() {});
      return;
    }
    // 멀티라인 — 사용자 확인 후 일괄 추가.
    final ok = await _confirmBulkAdd(lines.length);
    if (!mounted) return;
    if (ok != true) {
      // 취소 — \n 제거하여 단일 row 로 복구 (paste 전 상태 회복은 어렵지만 cursor 정상화).
      _titleCtrl.text = lines.join(' ');
      _titleCtrl.selection = TextSelection.collapsed(
        offset: _titleCtrl.text.length,
      );
      setState(() {});
      return;
    }
    _submitBulk(lines);
  }

  Future<bool?> _confirmBulkAdd(int n) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('bulk-paste-dialog'),
        title: const Text('일괄 추가'),
        content: Text('$n개의 항목을 같은 카테고리 / 일정으로 한 번에 추가하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            key: const ValueKey('bulk-paste-confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('$n건 추가'),
          ),
        ],
      ),
    );
  }

  /// task ↔ note 토글. note 로 바꿀 때는 일정 관련 state 를 안전하게 reset.
  void _setType(TodoType t) {
    if (t == _type) return;
    setState(() {
      _type = t;
      if (t == TodoType.note) {
        _dueAt = null;
        _allDay = true;
        _addToCalendar = false;
      }
    });
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

  /// 빠른 칩 — 날짜만 지정 (시간 = 자정, allDay = true).
  /// 사용자가 같은 칩을 다시 누르면 토글 해제 (= dueAt 비우기).
  void _setQuickDate(DateTime date) {
    final d0 = DateTime(date.year, date.month, date.day);
    setState(() {
      if (_dueAt != null && _allDay && _isSameDate(_dueAt!, d0)) {
        _dueAt = null;
        _allDay = true;
        _addToCalendar = false;
      } else {
        _dueAt = d0;
        _allDay = true;
      }
    });
  }

  static bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime _today() {
    final now = (widget.now ?? DateTime.now)();
    return DateTime(now.year, now.month, now.day);
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
                    _isEditMode ? '할 일 편집' : '새 할 일',
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
                    // multi-line 허용 — 메모장 → 앱 멀티라인 paste 가 \n 그대로 들어와
                    // [_onTitleChanged] 가 bulk paste 로 감지. 평소 1줄 입력 시각은 minLines.
                    minLines: 1,
                    maxLines: 5,
                    maxLength: 1000,
                    keyboardType: TextInputType.multiline,
                    // edit 모드에서는 bulk paste 가 의미 없으므로 단순 setState 만.
                    onChanged: _isEditMode
                        ? (_) => setState(() {})
                        : _onTitleChanged,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      hintText: _isEditMode
                          ? '제목을 입력하세요'
                          : '무엇을 할까요?  (여러 줄 paste = 일괄 추가)',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: AppTokens.space12),
                  // v1.2 — 상세 메모 토글 + multi-line TextField.
                  _DescriptionToggle(
                    expanded: _showDescription,
                    onToggle: () =>
                        setState(() => _showDescription = !_showDescription),
                  ),
                  if (_showDescription) ...[
                    const SizedBox(height: AppTokens.space8),
                    TextField(
                      key: const ValueKey('add-todo-description'),
                      controller: _descriptionCtrl,
                      minLines: 3,
                      maxLines: 8,
                      maxLength: 5000,
                      keyboardType: TextInputType.multiline,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: '상세 메모 (선택)',
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                    ),
                  ],
                  const SizedBox(height: AppTokens.space16),
                  _SectionLabel(text: '카테고리'),
                  const SizedBox(height: AppTokens.space8),
                  _CategoryChips(
                    selected: _category,
                    onSelect: (c) => setState(() => _category = c),
                  ),
                  const SizedBox(height: AppTokens.space16),
                  _SectionLabel(text: '종류'),
                  const SizedBox(height: AppTokens.space8),
                  _TypeToggle(selected: _type, onSelect: _setType),
                  const SizedBox(height: AppTokens.space16),
                  // note 면 일정 영역 자체를 숨김 — 의미 없음.
                  if (_type == TodoType.task) ...[
                    _SectionLabel(text: '일정'),
                    const SizedBox(height: AppTokens.space8),
                    _QuickDueChips(
                      today: _today(),
                      dueAt: _dueAt,
                      allDay: _allDay,
                      onSelectDate: _setQuickDate,
                      onPickTime: _pickTime,
                    ),
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
                  ],
                  const SizedBox(height: AppTokens.space20),
                  _Actions(
                    canSubmit: _canSubmit,
                    onSubmit: _submit,
                    submitLabel: _isEditMode ? '저장' : '추가',
                  ),
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
        ? category.color.withValues(alpha: 0.22)
        : theme.colorScheme.surfaceContainerHighest;
    final fg = selected
        ? category.color
        : theme.colorScheme.onSurface.withValues(alpha: 0.78);

    // 선택 시 outline 도 함께 적용 — alpha 변화만으로는 시각 대비가 약했다.
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTokens.radiusFull),
      side: selected
          ? BorderSide(color: category.color, width: 1.6)
          : BorderSide.none,
    );

    return Material(
      color: bg,
      shape: shape,
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
  const _Actions({
    required this.canSubmit,
    required this.onSubmit,
    this.submitLabel = '추가',
  });

  final bool canSubmit;
  final VoidCallback onSubmit;
  final String submitLabel;

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
            child: Text(submitLabel),
          ),
        ),
      ],
    );
  }
}

/// v1.2 — 상세 메모 펼침/접힘 토글.
class _DescriptionToggle extends StatelessWidget {
  const _DescriptionToggle({required this.expanded, required this.onToggle});

  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        key: const ValueKey('add-todo-description-toggle'),
        onPressed: onToggle,
        icon: Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 18),
        label: const Text('상세 메모'),
        style: TextButton.styleFrom(
          foregroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.78),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.space8,
            vertical: AppTokens.space4,
          ),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

/// v1.1 — task / note segmented 토글. note 면 일정 영역이 사라지고 단순 메모로 저장된다.
class _TypeToggle extends StatelessWidget {
  const _TypeToggle({required this.selected, required this.onSelect});

  final TodoType selected;
  final ValueChanged<TodoType> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppTokens.space8,
      runSpacing: AppTokens.space8,
      children: [
        _TypeChip(
          key: const ValueKey('type-task'),
          label: '할 일',
          icon: Icons.check_box_outline_blank_rounded,
          selected: selected == TodoType.task,
          onTap: () => onSelect(TodoType.task),
        ),
        _TypeChip(
          key: const ValueKey('type-note'),
          label: '메모',
          icon: Icons.sticky_note_2_outlined,
          selected: selected == TodoType.note,
          onTap: () => onSelect(TodoType.note),
        ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bg = selected
        ? scheme.primaryContainer
        : scheme.surfaceContainerHighest;
    final fg = selected
        ? scheme.onPrimaryContainer
        : scheme.onSurface.withValues(alpha: 0.78);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTokens.radiusFull),
      side: selected
          ? BorderSide(color: scheme.primary, width: 1.4)
          : BorderSide.none,
    );

    return Material(
      color: bg,
      shape: shape,
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
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: AppTokens.space8),
              Text(
                label,
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

/// 빠른 dueAt 선택 칩 — "오늘 / 내일 / 다음주 / 시간 지정".
///
/// "다음주" 는 오늘로부터 7일 후 자정 (= 1주일 뒤) 으로 정의 — "다음주 월요일" 처럼
/// 주의 시작 정의에 따라 의미가 달라지는 모호함을 피하기 위함.
///
/// 같은 칩을 다시 누르면 toggle 해제 → dueAt 비우기. "시간 지정" 만 별개 동작 —
/// 항상 [showTimePicker] 를 띄움 (현재 _dueAt 보존 + 시간만 변경).
class _QuickDueChips extends StatelessWidget {
  const _QuickDueChips({
    required this.today,
    required this.dueAt,
    required this.allDay,
    required this.onSelectDate,
    required this.onPickTime,
  });

  final DateTime today;
  final DateTime? dueAt;
  final bool allDay;
  final void Function(DateTime date) onSelectDate;
  final VoidCallback onPickTime;

  bool _isSelectedDate(DateTime target) {
    final d = dueAt;
    if (d == null || !allDay) return false;
    return d.year == target.year &&
        d.month == target.month &&
        d.day == target.day;
  }

  @override
  Widget build(BuildContext context) {
    final tomorrow = today.add(const Duration(days: 1));
    final nextWeek = today.add(const Duration(days: 7));
    final timeChipSelected = dueAt != null && !allDay;

    return Wrap(
      spacing: AppTokens.space8,
      runSpacing: AppTokens.space8,
      children: [
        _QuickDueChip(
          key: const ValueKey('quick-due-today'),
          label: '오늘',
          icon: Icons.today_outlined,
          selected: _isSelectedDate(today),
          onTap: () => onSelectDate(today),
        ),
        _QuickDueChip(
          key: const ValueKey('quick-due-tomorrow'),
          label: '내일',
          icon: Icons.update_outlined,
          selected: _isSelectedDate(tomorrow),
          onTap: () => onSelectDate(tomorrow),
        ),
        _QuickDueChip(
          key: const ValueKey('quick-due-next-week'),
          label: '다음주',
          icon: Icons.next_week_outlined,
          selected: _isSelectedDate(nextWeek),
          onTap: () => onSelectDate(nextWeek),
        ),
        _QuickDueChip(
          key: const ValueKey('quick-due-time'),
          label: '시간 지정',
          icon: Icons.schedule_outlined,
          selected: timeChipSelected,
          onTap: onPickTime,
        ),
      ],
    );
  }
}

class _QuickDueChip extends StatelessWidget {
  const _QuickDueChip({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bg = selected
        ? scheme.primaryContainer
        : scheme.surfaceContainerHighest;
    final fg = selected
        ? scheme.onPrimaryContainer
        : scheme.onSurface.withValues(alpha: 0.78);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTokens.radiusFull),
      side: selected
          ? BorderSide(color: scheme.primary, width: 1.4)
          : BorderSide.none,
    );

    return Material(
      color: bg,
      shape: shape,
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
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: AppTokens.space8),
              Text(
                label,
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

/// AddTodoSheet 가 사용자가 제출한 form 데이터를 한 묶음으로 전달.
class AddTodoSubmission {
  const AddTodoSubmission({
    required this.title,
    required this.category,
    required this.dueAt,
    this.isAllDay = false,
    required this.addToCalendar,
    this.type = TodoType.task,
    this.description,
  });

  final String title;
  final Category category;
  final DateTime? dueAt;

  /// dueAt 이 "하루 종일" 의미인지. dueAt 이 null 이면 의미 없음 (false).
  /// AddTodoController 가 CalendarService.createEventForTodo 에 전달.
  final bool isAllDay;

  final bool addToCalendar;

  /// v1.1 — task / note 구분. note 면 dueAt/addToCalendar 는 강제로 무효 처리됨.
  final TodoType type;

  /// v1.2 — 상세 메모 (long text). null / 빈 문자열 모두 "없음" 의미.
  final String? description;
}
