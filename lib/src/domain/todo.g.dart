// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'todo.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Todo _$TodoFromJson(Map<String, dynamic> json) => _Todo(
  id: json['id'] as String,
  title: json['title'] as String,
  category: $enumDecode(_$CategoryEnumMap, json['category']),
  dueAt: json['dueAt'] == null ? null : DateTime.parse(json['dueAt'] as String),
  doneAt: json['doneAt'] == null
      ? null
      : DateTime.parse(json['doneAt'] as String),
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  calendarEventId: json['calendarEventId'] as String?,
);

Map<String, dynamic> _$TodoToJson(_Todo instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'category': _$CategoryEnumMap[instance.category]!,
  'dueAt': instance.dueAt?.toIso8601String(),
  'doneAt': instance.doneAt?.toIso8601String(),
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  'calendarEventId': instance.calendarEventId,
};

const _$CategoryEnumMap = {
  Category.work: 'work',
  Category.personalDev: 'personal_dev',
  Category.daily: 'daily',
  Category.longterm: 'longterm',
  Category.idea: 'idea',
};
