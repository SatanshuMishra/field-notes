import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'database.dart';

final class MigrationException implements Exception {
  const MigrationException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class Migration {
  const Migration({required this.name, required this.sql});

  final String name;
  final String sql;
}

final class MigrationReport {
  const MigrationReport({required this.applied, required this.backupPath});

  final List<String> applied;
  final String? backupPath;
}

Uri? _packageLibrary() {
  try {
    return Isolate.resolvePackageUriSync(
      Uri.parse('package:relay_server/relay_server.dart'),
    );
  } on Object {
    return null;
  }
}

String defaultMigrationsDirectory() {
  final Uri? library = _packageLibrary();
  if (library != null && library.isScheme('file')) {
    final String candidate = p.normalize(
      p.join(p.dirname(library.toFilePath()), '..', 'migrations'),
    );
    if (Directory(candidate).existsSync()) {
      return candidate;
    }
  }
  return p.normalize(
    p.join(p.dirname(Platform.script.toFilePath()), '..', 'migrations'),
  );
}

List<Migration> loadMigrations(String directory) {
  final Directory folder = Directory(directory);
  if (!folder.existsSync()) {
    throw MigrationException('No migrations folder at $directory');
  }
  final List<File> files = <File>[
    for (final FileSystemEntity entity in folder.listSync())
      if (entity is File && entity.path.endsWith('.sql')) entity,
  ]..sort((File a, File b) => p.basename(a.path).compareTo(p.basename(b.path)));
  return <Migration>[
    for (final File file in files)
      Migration(name: p.basename(file.path), sql: file.readAsStringSync()),
  ];
}

String backupTimestamp(DateTime time) {
  final DateTime utc = time.toUtc();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${utc.year.toString().padLeft(4, '0')}${two(utc.month)}'
      '${two(utc.day)}T${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z';
}

MigrationReport migrate({
  required String databasePath,
  required String migrationsDirectory,
  required DateTime now,
}) {
  final List<Migration> migrations = loadMigrations(migrationsDirectory);
  Directory(p.dirname(databasePath)).createSync(recursive: true);
  final RelayDatabase database = RelayDatabase.open(databasePath);
  try {
    final bool hasTables =
        database.count(
          "SELECT count(*) FROM sqlite_master WHERE type = 'table'",
        ) >
        0;
    database.execute(
      'CREATE TABLE IF NOT EXISTS schema_migrations ('
      'name TEXT PRIMARY KEY NOT NULL, applied_at INTEGER NOT NULL) STRICT',
    );
    final Set<String> done = <String>{
      for (final Row row in database.select(
        'SELECT name FROM schema_migrations',
      ))
        row['name'] as String,
    };
    final List<Migration> pending = <Migration>[
      for (final Migration migration in migrations)
        if (!done.contains(migration.name)) migration,
    ];
    if (pending.isEmpty) {
      return const MigrationReport(applied: <String>[], backupPath: null);
    }
    final String? backupPath = hasTables
        ? _backUp(database, databasePath, now)
        : null;
    for (final Migration migration in pending) {
      try {
        database.transaction(() {
          database.execute(migration.sql);
          database.execute(
            'INSERT INTO schema_migrations (name, applied_at) VALUES (?, ?)',
            <Object?>[migration.name, toMillis(now)],
          );
        });
      } on SqliteException catch (error) {
        throw MigrationException(
          'Migration ${migration.name} failed: ${error.message}',
        );
      }
    }
    return MigrationReport(
      applied: <String>[
        for (final Migration migration in pending) migration.name,
      ],
      backupPath: backupPath,
    );
  } finally {
    database.close();
  }
}

String _backUp(RelayDatabase database, String databasePath, DateTime now) {
  final String base = '$databasePath.bak-${backupTimestamp(now)}';
  String target = base;
  for (int attempt = 2; File(target).existsSync(); attempt++) {
    target = '$base-$attempt';
  }
  database.execute('VACUUM INTO ?', <Object?>[target]);
  return target;
}
