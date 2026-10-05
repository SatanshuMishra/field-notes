import 'package:drift/drift.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/sync/change_recorder.dart';
import 'package:field_notes/data/sync/synced_tables.dart';

const List<String> _valueFields = <String>['value'];

class JournalSettingsStore {
  JournalSettingsStore(this._db, this._recorder);

  final AppDatabase _db;
  final ChangeRecorder _recorder;

  Future<void> put(String key, String value) {
    return _db.transaction(() async {
      final JournalSetting? existing = await _row(key);
      final String clocks = await _recorder.stamp(
        table: SyncedTables.journalSettings,
        rowId: key,
        fields: existing == null
            ? SyncedTables.journalSettingFields
            : _valueFields,
        currentClocks: existing?.fieldClocks ?? '{}',
      );
      await _db
          .into(_db.journalSettings)
          .insertOnConflictUpdate(
            JournalSettingsCompanion.insert(
              key: key,
              value: value,
              fieldClocks: Value(clocks),
            ),
          );
    });
  }

  Future<String?> read(String key) async {
    return (await _row(key))?.value;
  }

  Stream<Map<String, String>> watch() {
    return _db
        .tableUpdates(TableUpdateQuery.onTable(_db.journalSettings))
        .asyncMap((Set<TableUpdate> _) => _readAll());
  }

  Future<Map<String, String>> _readAll() async {
    final List<JournalSetting> rows = await _db
        .select(_db.journalSettings)
        .get();
    return <String, String>{
      for (final JournalSetting row in rows) row.key: row.value,
    };
  }

  Future<JournalSetting?> _row(String key) {
    return (_db.select(
      _db.journalSettings,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
  }
}
