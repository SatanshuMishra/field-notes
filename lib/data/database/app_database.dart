import 'package:drift/drift.dart';

import 'connection.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [MediaBlobs, Days, Entries, EntryPhotos, Settings],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  AppDatabase.open() : super(openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (migrator) async {
        await migrator.createAll();
      },
      onUpgrade: (migrator, from, to) async {
        throw StateError(
          'Field Notes cannot migrate its database from schema version '
          '$from to $to. No changes were applied and your entries are '
          'intact. Please update Field Notes to a version that supports '
          'this database.',
        );
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON;');
      },
    );
  }
}
