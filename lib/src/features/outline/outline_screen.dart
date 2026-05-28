import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../ui/widgets/empty_state.dart';

/// 전체 트리 view — 5 카테고리 root + 자식들 펼침/접힘.
///
/// **placeholder** (현재 task: AppShell destination 등록만). 다음 task 에서 본격 트리
/// 렌더링 + 펼침/접힘 + 진척률 [N/M] 추가 예정.
class OutlineScreen extends StatelessWidget {
  const OutlineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppTokens.space24),
      child: EmptyState(
        icon: Icons.account_tree_outlined,
        title: '전체보기 (Outline)',
        subtitle: '카테고리 / 폴더 / 메모 트리 전체를 한 화면에 — 곧 도착합니다.',
      ),
    );
  }
}
