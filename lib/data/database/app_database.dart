import 'package:drift/drift.dart';

import 'connection.dart';
import 'sync_tables.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    MediaBlobs,
    Days,
    Entries,
    EntryPhotos,
    Settings,
    JournalSettings,
    SyncOutbox,
    SyncRecordSeqs,
    SyncTextBases,
    SyncStates,
    SyncHeldStates,
    SyncUploads,
    SyncMediaCache,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  AppDatabase.open() : super(openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (migrator) async {
        await migrator.createAll();
      },
      onUpgrade: (migrator, from, to) async {
        if ((from != 1 && from != 2) || to != 3) {
          throw StateError(
            'Field Notes cannot migrate its database from schema version '
            '$from to $to. No changes were applied and your entries are '
            'intact. Please update Field Notes to a version that supports '
            'this database.',
          );
        }
        await transaction(() async {
          if (from == 1) {
            await migrator.addColumn(entries, entries.peaks);
          }
          await migrator.addColumn(entries, entries.title);
          await customStatement('PRAGMA user_version = $to');
        });
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON;');
      },
    );
  }
}
