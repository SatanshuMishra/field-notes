import 'package:drift/drift.dart';

class JournalSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  TextColumn get fieldClocks => text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {key};
}

@TableIndex(
  name: 'sync_outbox_record',
  columns: {#recordTable, #rowId},
  unique: true,
)
class SyncOutbox extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get recordTable => text()();
  TextColumn get rowId => text()();
  TextColumn get changeId => text().nullable()();
  IntColumn get enqueuedAt => integer()();
}

class SyncRecordSeqs extends Table {
  TextColumn get recordKey => text()();
  TextColumn get recordTable => text()();
  TextColumn get rowId => text()();
  IntColumn get seq => integer()();

  @override
  Set<Column> get primaryKey => {recordKey};
}

class SyncTextBases extends Table {
  TextColumn get entryId => text()();
  TextColumn get textContent => text().named('text')();
  TextColumn get clock => text()();
  TextColumn get version => text()();

  @override
  Set<Column> get primaryKey => {entryId};
}

class SyncStates extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

class SyncHeldStates extends Table {
  TextColumn get recordKey => text()();
  TextColumn get stateJson => text()();
  IntColumn get heldAt => integer()();

  @override
  Set<Column> get primaryKey => {recordKey};
}

class SyncUploads extends Table {
  TextColumn get blobId => text()();
  TextColumn get blobName => text()();
  TextColumn get uploadId => text()();
  IntColumn get totalBytes => integer()();
  IntColumn get partCount => integer()();
  TextColumn get ackedParts => text().withDefault(const Constant('[]'))();
  TextColumn get partsDir => text().nullable()();
  TextColumn get status => text()();

  @override
  Set<Column> get primaryKey => {blobId};
}

class SyncMediaCache extends Table {
  TextColumn get blobId => text()();
  IntColumn get downloadedAt => integer().nullable()();
  IntColumn get lastOpenedAt => integer().nullable()();
  BoolColumn get uploaded => boolean().withDefault(const Constant(false))();
  TextColumn get reportedState => text().withDefault(const Constant('none'))();

  @override
  Set<Column> get primaryKey => {blobId};
}
