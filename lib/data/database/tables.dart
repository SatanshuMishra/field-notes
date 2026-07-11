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

  @override
  Set<Column> get primaryKey => {id};
}

class Entries extends Table {
  TextColumn get id => text()();
  TextColumn get dayId => text().references(Days, #id)();
  TextColumn get type => text()();
  TextColumn get textContent => text().nullable()();
  TextColumn get mediaId => text().nullable().references(MediaBlobs, #id)();
  TextColumn get thumbnailMediaId =>
      text().nullable().references(MediaBlobs, #id)();
  IntColumn get durationMs => integer().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class EntryPhotos extends Table {
  TextColumn get id => text()();
  TextColumn get entryId => text().references(Entries, #id)();
  TextColumn get mediaId => text().references(MediaBlobs, #id)();
  IntColumn get sortOrder => integer()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();

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

  @override
  Set<Column> get primaryKey => {id};
}

class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
