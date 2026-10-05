import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'admin.dart';
import 'blobs.dart';
import 'config.dart';
import 'database.dart';

const String manifestExtension = '.manifest';
const String manifestHeader = 'field-notes-relay-manifest\t1';
const String _recordKind = 'record';
const String _blobKind = 'blob';

final class BackupException implements Exception {
  const BackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class ManifestEntry {
  const ManifestEntry({
    required this.kind,
    required this.accountId,
    required this.key,
  });

  final String kind;
  final String accountId;
  final String key;

  bool get isRecord => kind == _recordKind;

  String get line => '$kind\t$accountId\t$key';

  String get label => '$kind $accountId/$key';
}

final class SnapshotResult {
  const SnapshotResult({
    required this.databasePath,
    required this.manifestPath,
    required this.records,
    required this.blobs,
  });

  final String databasePath;
  final String manifestPath;
  final int records;
  final int blobs;
}

String manifestPathFor(String snapshotPath) =>
    '$snapshotPath$manifestExtension';

String _integrity(RelayDatabase database) {
  final List<String> lines = <String>[
    for (final Row row in database.select('PRAGMA integrity_check'))
      '${row.columnAt(0)}',
  ];
  return lines.join('; ');
}

List<ManifestEntry> _entries(RelayDatabase database) => <ManifestEntry>[
  for (final Row row in database.select(
    'SELECT account_id, record_key FROM records ORDER BY account_id, record_key',
  ))
    ManifestEntry(
      kind: _recordKind,
      accountId: row['account_id'] as String,
      key: row['record_key'] as String,
    ),
  for (final Row row in database.select(
    'SELECT account_id, name FROM blobs ORDER BY account_id, name',
  ))
    ManifestEntry(
      kind: _blobKind,
      accountId: row['account_id'] as String,
      key: row['name'] as String,
    ),
];

SnapshotResult snapshotDatabase({
  required String databasePath,
  required String target,
}) {
  final String manifestPath = manifestPathFor(target);
  if (File(target).existsSync() || File(manifestPath).existsSync()) {
    throw BackupException('$target already exists');
  }
  Directory(p.dirname(target)).createSync(recursive: true);
  final RelayDatabase source = RelayDatabase.open(databasePath, create: false);
  try {
    source.execute('VACUUM INTO ?', <Object?>[target]);
  } finally {
    source.close();
  }
  final List<ManifestEntry> entries;
  final RelayDatabase copy = RelayDatabase.openCopy(target, readOnly: true);
  try {
    final String integrity = _integrity(copy);
    if (integrity != 'ok') {
      throw BackupException('The copy failed its integrity check: $integrity');
    }
    entries = _entries(copy);
  } on Object {
    copy.close();
    File(target).deleteSync();
    rethrow;
  }
  copy.close();
  final File staged = File('$manifestPath.partial');
  staged.writeAsStringSync(
    <String>[
      manifestHeader,
      for (final ManifestEntry entry in entries) entry.line,
    ].join('\n'),
    flush: true,
  );
  staged.renameSync(manifestPath);
  return SnapshotResult(
    databasePath: target,
    manifestPath: manifestPath,
    records: entries.where((ManifestEntry entry) => entry.isRecord).length,
    blobs: entries.where((ManifestEntry entry) => !entry.isRecord).length,
  );
}

List<ManifestEntry> readManifest(String manifestPath) {
  final File file = File(manifestPath);
  if (!file.existsSync()) {
    throw BackupException('No manifest at $manifestPath');
  }
  final List<String> lines = file.readAsLinesSync();
  if (lines.isEmpty || lines.first != manifestHeader) {
    throw BackupException('$manifestPath is not a relay manifest');
  }
  return <ManifestEntry>[
    for (final String line in lines.skip(1))
      if (line.isNotEmpty) _parseEntry(line, manifestPath),
  ];
}

ManifestEntry _parseEntry(String line, String manifestPath) {
  final List<String> fields = line.split('\t');
  if (fields.length != 3 ||
      (fields[0] != _recordKind && fields[0] != _blobKind)) {
    throw BackupException('$manifestPath holds a malformed line');
  }
  return ManifestEntry(kind: fields[0], accountId: fields[1], key: fields[2]);
}

List<String> verifyCopy({
  required String databasePath,
  required String mediaDirectory,
  required String manifestPath,
}) {
  final List<ManifestEntry> entries = readManifest(manifestPath);
  final RelayDatabase copy;
  try {
    copy = RelayDatabase.openCopy(databasePath, readOnly: true);
  } on Object {
    return <String>['missing database $databasePath'];
  }
  try {
    final String integrity = _integrity(copy);
    if (integrity != 'ok') {
      return <String>['integrity check failed: $integrity'];
    }
    return <String>[
      for (final ManifestEntry entry in entries)
        if (!_present(copy, mediaDirectory, entry)) 'missing ${entry.label}',
    ];
  } finally {
    copy.close();
  }
}

bool _present(RelayDatabase copy, String mediaDirectory, ManifestEntry entry) {
  if (entry.isRecord) {
    return copy.count(
          'SELECT count(*) FROM records WHERE account_id = ? AND record_key = ?',
          <Object?>[entry.accountId, entry.key],
        ) >
        0;
  }
  final Row? row = copy.selectOne(
    'SELECT size FROM blobs WHERE account_id = ? AND name = ?',
    <Object?>[entry.accountId, entry.key],
  );
  if (row == null || !isBlobName(entry.key)) {
    return false;
  }
  final File file = File(blobPath(mediaDirectory, entry.accountId, entry.key));
  return file.existsSync() && file.lengthSync() == row['size'] as int;
}

int runBackupCommand(
  List<String> arguments, {
  required RelayConfig config,
  required StringSink out,
  required StringSink err,
}) {
  final String command = arguments.isEmpty ? '' : arguments.first;
  final List<String> rest = arguments.isEmpty
      ? const <String>[]
      : arguments.sublist(1);
  try {
    switch (command) {
      case 'snapshot-db':
        final String? target = optionValue(rest, '--to');
        if (target == null) {
          err.writeln('Usage: relay snapshot-db --to <file>');
          return exitUsage;
        }
        final SnapshotResult result = snapshotDatabase(
          databasePath: config.databasePath,
          target: target,
        );
        out.writeln('snapshot\t${result.databasePath}');
        out.writeln('manifest\t${result.manifestPath}');
        out.writeln('records\t${result.records}');
        out.writeln('blobs\t${result.blobs}');
        return exitOk;
      case 'verify-copy':
        final String? database = optionValue(rest, '--db');
        final String? media = optionValue(rest, '--media');
        final String? manifest = optionValue(rest, '--manifest');
        if (database == null || media == null || manifest == null) {
          err.writeln(
            'Usage: relay verify-copy --db <file> --media <dir> '
            '--manifest <file>',
          );
          return exitUsage;
        }
        final List<String> problems = verifyCopy(
          databasePath: database,
          mediaDirectory: media,
          manifestPath: manifest,
        );
        if (problems.isNotEmpty) {
          problems.forEach(err.writeln);
          return exitFailure;
        }
        out.writeln('ok\t$database');
        return exitOk;
      default:
        err.writeln('Unknown backup command $command');
        return exitUsage;
    }
  } on BackupException catch (error) {
    err.writeln(error.message);
    return exitFailure;
  } on SqliteException catch (error) {
    err.writeln('Database error: ${error.message}');
    return exitFailure;
  } on FileSystemException catch (error) {
    err.writeln('File error: ${error.message} ${error.path ?? ''}');
    return exitFailure;
  }
}
