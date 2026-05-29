import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme.dart';
import '../../domain/group.dart';
import 'groups_controller.dart';

const _uuid = Uuid();

/// 새 그룹 추가 다이얼로그. [AddCategoryDialog] 미러 (아이콘 picker 는 생략 — 그룹은
/// 사이드바 헤더에 색 dot + label 만 쓴다).
///
/// label TextField + 16 색 palette. 확인 시 [GroupsController.add] 호출.
/// id 는 `grp-<uuid>`, sortOrder 100.
class AddGroupDialog extends ConsumerStatefulWidget {
  const AddGroupDialog({super.key});

  /// 다이얼로그 표시 + 결과 반환 (true = 추가됨, false/null = 취소).
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (_) => const AddGroupDialog(),
    );
  }

  /// 사용자가 고를 16 색 palette (AddCategoryDialog 와 동일 세트).
  @visibleForTesting
  static const colorPalette = <int>[
    0xFFEC4899, // pink
    0xFFF97316, // orange
    0xFF84CC16, // lime
    0xFF06B6D4, // cyan
    0xFF3B82F6, // blue
    0xFF6366F1, // indigo
    0xFFA855F7, // violet
    0xFFD946EF, // fuchsia
    0xFFF43F5E, // rose
    0xFF14B8A6, // teal
    0xFF22C55E, // green
    0xFF65A30D, // dark lime
    0xFF0EA5E9, // sky
    0xFF7C3AED, // purple
    0xFFE11D48, // dark rose
    0xFF6B7280, // gray
  ];

  @override
  ConsumerState<AddGroupDialog> createState() => _AddGroupDialogState();
}

class _AddGroupDialogState extends ConsumerState<AddGroupDialog> {
  final _labelCtrl = TextEditingController();
  int _selectedColor = AddGroupDialog.colorPalette.first;
  bool _submitted = false;

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  bool get _canSubmit => _labelCtrl.text.trim().isNotEmpty && !_submitted;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _submitted = true);
    final controller = ref.read(groupsControllerProvider);

    final newGroup = Group(
      id: 'grp-${_uuid.v4()}',
      label: _labelCtrl.text.trim(),
      colorValue: _selectedColor,
      sortOrder: 100,
      isBuiltin: false,
    );
    await controller.add(newGroup);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('새 그룹'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _labelCtrl,
                autofocus: true,
                maxLength: 30,
                decoration: const InputDecoration(
                  labelText: '이름',
                  hintText: '예: 회사, 사이드프로젝트',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppTokens.space16),
              Text('색', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppTokens.space8),
              _ColorPalette(
                colors: AddGroupDialog.colorPalette,
                selected: _selectedColor,
                onSelect: (c) => setState(() => _selectedColor = c),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitted ? null : () => Navigator.of(context).pop(false),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _canSubmit ? _submit : null,
          child: const Text('추가'),
        ),
      ],
    );
  }
}

class _ColorPalette extends StatelessWidget {
  const _ColorPalette({
    required this.colors,
    required this.selected,
    required this.onSelect,
  });

  final List<int> colors;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppTokens.space8,
      runSpacing: AppTokens.space8,
      children: [
        for (final c in colors)
          GestureDetector(
            onTap: () => onSelect(c),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Color(c),
                shape: BoxShape.circle,
                border: Border.all(
                  color: c == selected
                      ? Theme.of(context).colorScheme.onSurface
                      : Colors.transparent,
                  width: 2.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
