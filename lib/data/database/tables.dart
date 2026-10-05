import 'package:drift/drift.dart';

@TableIndex.sql(
  'CREATE UNIQUE INDEX days_date_active '
  'ON days (date) WHERE deleted_at IS NULL;',
)
class Days extends Table {
  TextColumn get id => text()();
  TextColumn get date => text()();
  TextColumn get moodId => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
  TextColumn get fieldClocks => text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {id};
}

class Entries extends Table {
  TextColumn get id => text()();
  TextColumn get dayId => text()();
  TextColumn get type => text()();
  TextColumn get textContent => text().nullable()();
  TextColumn get mediaId => text().nullable()();
  TextColumn get thumbnailMediaId => text().nullable()();
  IntColumn get durationMs => integer().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
  TextColumn get conflictSourceDevice => text().nullable()();
  TextColumn get textVersion => text().withDefault(const Constant('{}'))();
  TextColumn get fieldClocks => text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {id};
}

class EntryPhotos extends Table {
  TextColumn get id => text()();
  TextColumn get entryId => text()();
  TextColumn get mediaId => text()();
  IntColumn get sortOrder => integer()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
  TextColumn get fieldClocks => text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {id};
}

class MediaBlobs extends Table {
  TextColumn get id => text()();
  TextColumn get relPath => text()();
  TextColumn get mime => text()();
  TextColumn get kind => text()();
  IntColumn get bytes => integer()();
  IntColumn get width => integer().nullable()();
  IntColumn get height => integer().nullable()();
  IntColumn get durationMs => integer().nullable()();
  IntColumn get createdAt => integer()();
  TextColumn get posterId => text().nullable()();
  TextColumn get fieldClocks => text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {id};
}

class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
