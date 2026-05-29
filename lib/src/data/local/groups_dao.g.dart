// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'groups_dao.dart';

// ignore_for_file: type=lint
mixin _$GroupsDaoMixin on DatabaseAccessor<AppDatabase> {
  $GroupsTable get groups => attachedDatabase.groups;
  $CategoriesTable get categories => attachedDatabase.categories;
  GroupsDaoManager get managers => GroupsDaoManager(this);
}

class GroupsDaoManager {
  final _$GroupsDaoMixin _db;
  GroupsDaoManager(this._db);
  $$GroupsTableTableManager get groups =>
      $$GroupsTableTableManager(_db.attachedDatabase, _db.groups);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
}
