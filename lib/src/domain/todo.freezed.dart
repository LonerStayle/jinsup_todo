// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'todo.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Todo {

 String get id; String get title;@JsonKey(fromJson: _categoryFromJson, toJson: _categoryToJson) Category get category; DateTime? get dueAt; DateTime? get doneAt; DateTime get createdAt; DateTime get updatedAt; String? get calendarEventId; String? get parentId; TodoType get type; int get sortOrder;
/// Create a copy of Todo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TodoCopyWith<Todo> get copyWith => _$TodoCopyWithImpl<Todo>(this as Todo, _$identity);

  /// Serializes this Todo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Todo&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.category, category) || other.category == category)&&(identical(other.dueAt, dueAt) || other.dueAt == dueAt)&&(identical(other.doneAt, doneAt) || other.doneAt == doneAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.calendarEventId, calendarEventId) || other.calendarEventId == calendarEventId)&&(identical(other.parentId, parentId) || other.parentId == parentId)&&(identical(other.type, type) || other.type == type)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,category,dueAt,doneAt,createdAt,updatedAt,calendarEventId,parentId,type,sortOrder);

@override
String toString() {
  return 'Todo(id: $id, title: $title, category: $category, dueAt: $dueAt, doneAt: $doneAt, createdAt: $createdAt, updatedAt: $updatedAt, calendarEventId: $calendarEventId, parentId: $parentId, type: $type, sortOrder: $sortOrder)';
}


}

/// @nodoc
abstract mixin class $TodoCopyWith<$Res>  {
  factory $TodoCopyWith(Todo value, $Res Function(Todo) _then) = _$TodoCopyWithImpl;
@useResult
$Res call({
 String id, String title,@JsonKey(fromJson: _categoryFromJson, toJson: _categoryToJson) Category category, DateTime? dueAt, DateTime? doneAt, DateTime createdAt, DateTime updatedAt, String? calendarEventId, String? parentId, TodoType type, int sortOrder
});


$CategoryCopyWith<$Res> get category;

}
/// @nodoc
class _$TodoCopyWithImpl<$Res>
    implements $TodoCopyWith<$Res> {
  _$TodoCopyWithImpl(this._self, this._then);

  final Todo _self;
  final $Res Function(Todo) _then;

/// Create a copy of Todo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? category = null,Object? dueAt = freezed,Object? doneAt = freezed,Object? createdAt = null,Object? updatedAt = null,Object? calendarEventId = freezed,Object? parentId = freezed,Object? type = null,Object? sortOrder = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as Category,dueAt: freezed == dueAt ? _self.dueAt : dueAt // ignore: cast_nullable_to_non_nullable
as DateTime?,doneAt: freezed == doneAt ? _self.doneAt : doneAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,calendarEventId: freezed == calendarEventId ? _self.calendarEventId : calendarEventId // ignore: cast_nullable_to_non_nullable
as String?,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String?,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as TodoType,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of Todo
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CategoryCopyWith<$Res> get category {
  
  return $CategoryCopyWith<$Res>(_self.category, (value) {
    return _then(_self.copyWith(category: value));
  });
}
}


/// Adds pattern-matching-related methods to [Todo].
extension TodoPatterns on Todo {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Todo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Todo() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Todo value)  $default,){
final _that = this;
switch (_that) {
case _Todo():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Todo value)?  $default,){
final _that = this;
switch (_that) {
case _Todo() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String title, @JsonKey(fromJson: _categoryFromJson, toJson: _categoryToJson)  Category category,  DateTime? dueAt,  DateTime? doneAt,  DateTime createdAt,  DateTime updatedAt,  String? calendarEventId,  String? parentId,  TodoType type,  int sortOrder)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Todo() when $default != null:
return $default(_that.id,_that.title,_that.category,_that.dueAt,_that.doneAt,_that.createdAt,_that.updatedAt,_that.calendarEventId,_that.parentId,_that.type,_that.sortOrder);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String title, @JsonKey(fromJson: _categoryFromJson, toJson: _categoryToJson)  Category category,  DateTime? dueAt,  DateTime? doneAt,  DateTime createdAt,  DateTime updatedAt,  String? calendarEventId,  String? parentId,  TodoType type,  int sortOrder)  $default,) {final _that = this;
switch (_that) {
case _Todo():
return $default(_that.id,_that.title,_that.category,_that.dueAt,_that.doneAt,_that.createdAt,_that.updatedAt,_that.calendarEventId,_that.parentId,_that.type,_that.sortOrder);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String title, @JsonKey(fromJson: _categoryFromJson, toJson: _categoryToJson)  Category category,  DateTime? dueAt,  DateTime? doneAt,  DateTime createdAt,  DateTime updatedAt,  String? calendarEventId,  String? parentId,  TodoType type,  int sortOrder)?  $default,) {final _that = this;
switch (_that) {
case _Todo() when $default != null:
return $default(_that.id,_that.title,_that.category,_that.dueAt,_that.doneAt,_that.createdAt,_that.updatedAt,_that.calendarEventId,_that.parentId,_that.type,_that.sortOrder);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Todo extends Todo {
  const _Todo({required this.id, required this.title, @JsonKey(fromJson: _categoryFromJson, toJson: _categoryToJson) required this.category, this.dueAt, this.doneAt, required this.createdAt, required this.updatedAt, this.calendarEventId, this.parentId, this.type = TodoType.task, this.sortOrder = 0}): super._();
  factory _Todo.fromJson(Map<String, dynamic> json) => _$TodoFromJson(json);

@override final  String id;
@override final  String title;
@override@JsonKey(fromJson: _categoryFromJson, toJson: _categoryToJson) final  Category category;
@override final  DateTime? dueAt;
@override final  DateTime? doneAt;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;
@override final  String? calendarEventId;
@override final  String? parentId;
@override@JsonKey() final  TodoType type;
@override@JsonKey() final  int sortOrder;

/// Create a copy of Todo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TodoCopyWith<_Todo> get copyWith => __$TodoCopyWithImpl<_Todo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TodoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Todo&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.category, category) || other.category == category)&&(identical(other.dueAt, dueAt) || other.dueAt == dueAt)&&(identical(other.doneAt, doneAt) || other.doneAt == doneAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.calendarEventId, calendarEventId) || other.calendarEventId == calendarEventId)&&(identical(other.parentId, parentId) || other.parentId == parentId)&&(identical(other.type, type) || other.type == type)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,category,dueAt,doneAt,createdAt,updatedAt,calendarEventId,parentId,type,sortOrder);

@override
String toString() {
  return 'Todo(id: $id, title: $title, category: $category, dueAt: $dueAt, doneAt: $doneAt, createdAt: $createdAt, updatedAt: $updatedAt, calendarEventId: $calendarEventId, parentId: $parentId, type: $type, sortOrder: $sortOrder)';
}


}

/// @nodoc
abstract mixin class _$TodoCopyWith<$Res> implements $TodoCopyWith<$Res> {
  factory _$TodoCopyWith(_Todo value, $Res Function(_Todo) _then) = __$TodoCopyWithImpl;
@override @useResult
$Res call({
 String id, String title,@JsonKey(fromJson: _categoryFromJson, toJson: _categoryToJson) Category category, DateTime? dueAt, DateTime? doneAt, DateTime createdAt, DateTime updatedAt, String? calendarEventId, String? parentId, TodoType type, int sortOrder
});


@override $CategoryCopyWith<$Res> get category;

}
/// @nodoc
class __$TodoCopyWithImpl<$Res>
    implements _$TodoCopyWith<$Res> {
  __$TodoCopyWithImpl(this._self, this._then);

  final _Todo _self;
  final $Res Function(_Todo) _then;

/// Create a copy of Todo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? category = null,Object? dueAt = freezed,Object? doneAt = freezed,Object? createdAt = null,Object? updatedAt = null,Object? calendarEventId = freezed,Object? parentId = freezed,Object? type = null,Object? sortOrder = null,}) {
  return _then(_Todo(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as Category,dueAt: freezed == dueAt ? _self.dueAt : dueAt // ignore: cast_nullable_to_non_nullable
as DateTime?,doneAt: freezed == doneAt ? _self.doneAt : doneAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,calendarEventId: freezed == calendarEventId ? _self.calendarEventId : calendarEventId // ignore: cast_nullable_to_non_nullable
as String?,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String?,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as TodoType,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of Todo
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CategoryCopyWith<$Res> get category {
  
  return $CategoryCopyWith<$Res>(_self.category, (value) {
    return _then(_self.copyWith(category: value));
  });
}
}

// dart format on
