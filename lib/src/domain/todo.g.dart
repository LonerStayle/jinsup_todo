// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'todo.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Todo _$TodoFromJson(Map<String, dynamic> json) => _Todo(
  id: json['id'] as String,
  title: json['title'] as String,
  category: _categoryFromJson(json['category']),
  dueAt: json['dueAt'] == null ? null : DateTime.parse(json['dueAt'] as String),
  doneAt: json['doneAt'] == null
      ? null
      : DateTime.parse(json['doneAt'] as String),
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  calendarEventId: json['calendarEventId'] as String?,
  parentId: json['parentId'] as String?,
  type: $enumDecodeNullable(_$TodoTypeEnumMap, json['type']) ?? TodoType.task,
  sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$TodoToJson(_Todo instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'category': _categoryToJson(instance.category),
  'dueAt': instance.dueAt?.toIso8601String(),
  'doneAt': instance.doneAt?.toIso8601String(),
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  'calendarEventId': instance.calendarEventId,
  'parentId': instance.parentId,
  'type': _$TodoTypeEnumMap[instance.type]!,
  'sortOrder': instance.sortOrder,
};

const _$TodoTypeEnumMap = {TodoType.task: 'task', TodoType.note: 'note'};
