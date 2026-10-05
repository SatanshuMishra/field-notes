import 'dart:convert';

import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/sync/merge/record_state.dart';
import 'package:field_notes/data/sync/synced_tables.dart';

class RecordReader {
  RecordReader(this._db);

  final AppDatabase _db;

  Future<RecordState?> read(String table, String rowId) async {
    final Map<String, dynamic>? row = await _rowJson(table, rowId);
    if (row == null) {
      return null;
    }
    final List<String> names = SyncedTables.fields[table]!;
    return RecordState(
      table: table,
      rowId: rowId,
      fields: <String, Object?>{
        for (final String name in names) name: row[name],
      },
      clocks: decodeFieldClocks(row['fieldClocks'] as String),
    );
  }

  Future<Map<String, dynamic>?> _rowJson(String table, String rowId) async {
    return switch (table) {
      SyncedTables.days => (await (_db.select(
        _db.days,
      )..where((t) => t.id.equals(rowId))).getSingleOrNull())?.toJson(),
      SyncedTables.entries => (await (_db.select(
        _db.entries,
      )..where((t) => t.id.equals(rowId))).getSingleOrNull())?.toJson(),
      SyncedTables.entryPhotos => (await (_db.select(
        _db.entryPhotos,
      )..where((t) => t.id.equals(rowId))).getSingleOrNull())?.toJson(),
      SyncedTables.mediaBlobs => (await (_db.select(
        _db.mediaBlobs,
      )..where((t) => t.id.equals(rowId))).getSingleOrNull())?.toJson(),
      SyncedTables.journalSettings => (await (_db.select(
        _db.journalSettings,
      )..where((t) => t.key.equals(rowId))).getSingleOrNull())?.toJson(),
      _ => throw ArgumentError.value(table, 'table', 'Not a synced table.'),
    };
  }
}

Map<String, String> decodeFieldClocks(String encoded) {
  final Object? decoded = jsonDecode(encoded);
  if (decoded is! Map<String, Object?> ||
      decoded.values.any((Object? clock) => clock is! String)) {
    throw FormatException(
      'Field clocks are not a JSON object of encoded clocks.',
      encoded,
    );
  }
  return decoded.cast<String, String>();
}
