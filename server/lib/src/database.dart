import 'dart:io';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';
import 'package:sync_protocol/sync_protocol.dart';

final class RelayException implements Exception {
  const RelayException(this.code, [this.message = '']);

  final SyncErrorCode code;
  final String message;

  @override
  String toString() => 'RelayException(${code.wireName})';
}

int toMillis(DateTime time) => time.toUtc().millisecondsSinceEpoch;

DateTime fromMillis(int millis) =>
    DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);

final class RelayDatabase {
  RelayDatabase._(this._db);

  factory RelayDatabase.open(String path, {bool create = true}) {
    if (!create && !File(path).existsSync()) {
      throw FileSystemException('No relay database', path);
    }
    final Database db = sqlite3.open(
      path,
      mode: create ? OpenMode.readWriteCreate : OpenMode.readWrite,
    );
    try {
      db.execute('PRAGMA busy_timeout = 10000');
      db.select('PRAGMA journal_mode = WAL');
      db.execute('PRAGMA synchronous = FULL');
    } catch (_) {
      db.close();
      rethrow;
    }
    return RelayDatabase._(db);
  }

  factory RelayDatabase.openCopy(String path, {bool readOnly = false}) {
    if (!File(path).existsSync()) {
      throw FileSystemException('No database copy', path);
    }
    final Database db = sqlite3.open(
      path,
      mode: readOnly ? OpenMode.readOnly : OpenMode.readWrite,
    );
    try {
      db.execute('PRAGMA busy_timeout = 10000');
      if (!readOnly) {
        db.select('PRAGMA journal_mode = DELETE');
      }
    } catch (_) {
      db.close();
      rethrow;
    }
    return RelayDatabase._(db);
  }

  static const String generationKey = 'generation';

  final Database _db;

  ResultSet select(
    String sql, [
    List<Object?> parameters = const <Object?>[],
  ]) => _db.select(sql, parameters);

  Row? selectOne(String sql, [List<Object?> parameters = const <Object?>[]]) {
    final ResultSet rows = _db.select(sql, parameters);
    return rows.isEmpty ? null : rows.first;
  }

  int count(String sql, [List<Object?> parameters = const <Object?>[]]) =>
      _db.select(sql, parameters).first.columnAt(0) as int;

  void execute(String sql, [List<Object?> parameters = const <Object?>[]]) =>
      _db.execute(sql, parameters);

  int get updatedRows => _db.updatedRows;

  bool hasTable(String name) =>
      count(
        "SELECT count(*) FROM sqlite_master WHERE type = 'table' AND name = ?",
        <Object?>[name],
      ) >
      0;

  T transaction<T>(T Function() body) {
    if (!_db.autocommit) {
      _db.execute('SAVEPOINT relay_nested');
      try {
        final T result = body();
        _db.execute('RELEASE relay_nested');
        return result;
      } catch (_) {
        _db.execute('ROLLBACK TO relay_nested');
        _db.execute('RELEASE relay_nested');
        rethrow;
      }
    }
    _db.execute('BEGIN IMMEDIATE');
    try {
      final T result = body();
      _db.execute('COMMIT');
      return result;
    } catch (_) {
      if (!_db.autocommit) {
        _db.execute('ROLLBACK');
      }
      rethrow;
    }
  }

  T read<T>(T Function() body) {
    if (!_db.autocommit) {
      return body();
    }
    _db.execute('BEGIN');
    try {
      final T result = body();
      _db.execute('COMMIT');
      return result;
    } catch (_) {
      if (!_db.autocommit) {
        _db.execute('ROLLBACK');
      }
      rethrow;
    }
  }

  String generation() {
    final Row? row = selectOne(
      'SELECT value FROM relay_meta WHERE key = ?',
      <Object?>[generationKey],
    );
    if (row == null) {
      throw StateError('The relay database has no generation');
    }
    return encodeBase64Url(row['value'] as Uint8List);
  }

  void close() => _db.close();
}
