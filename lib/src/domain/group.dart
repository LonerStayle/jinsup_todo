import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'group.freezed.dart';
part 'group.g.dart';

/// Solo Todo 의 그룹 (카테고리 상위 '큰분류').
///
/// 구조: 그룹(예: 회사) > 카테고리(예: 제품명) > todo 트리(태스크 > 하위).
/// 그룹은 v1.2 의 [Category] 인프라를 그대로 미러한 데이터 클래스다 — DB row 로
/// 저장되어 사용자가 추가 / 삭제 가능. builtin seed 는 없다 (그룹은 전부 사용자 정의).
///
/// 필드:
/// - [id] — DB / JSON 안정 키 (`grp-<uuid>`). 직렬화 키로 사용.
/// - [label] — 사용자에게 보여줄 한글 라벨.
/// - [colorValue] — `Color.value` 정수 표현 (예: `0xFF2A66FF`).
/// - [sortOrder] — sidebar 정렬 키 (작은 값 먼저). 기본 0.
/// - [isBuiltin] — 향후 builtin 분기 대비 플래그. 현재 모든 그룹 false.
///
/// 아이콘은 그룹 레벨에서는 두지 않는다 (사이드바 헤더는 색 dot + label 로 충분).
@freezed
abstract class Group with _$Group {
  const Group._();

  const factory Group({
    required String id,
    required String label,
    required int colorValue,
    @Default(0) int sortOrder,
    @Default(false) bool isBuiltin,
  }) = _Group;

  factory Group.fromJson(Map<String, dynamic> json) => _$GroupFromJson(json);

  /// 시각화용 [Color]. [colorValue] 를 [Color] 인스턴스로 감싼다.
  Color get color => Color(colorValue);
}
