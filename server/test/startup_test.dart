import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:relay_server/relay_server.dart';
import 'package:relay_server/src/database.dart';
import 'package:relay_server/src/migrations.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sync_protocol/sync_protocol.dart';
import 'package:test/test.dart';

import 'support/relay_harness.dart';

const List<String> relayTables = <String>[
  'accounts',
  'invites',
  'devices',
  'challenges',
  'sessions',
  'epoch_rotations',
  'epoch_deliveries',
  'relay_meta',
  'records',
  'account_seqs',
  'change_ids',
  'blobs',
  'uploads',
  'upload_parts',
  'mailboxes',
  'schema_migrations',
];

Future<Directory> scratchFolder() async {
  final Directory folder = await Directory.systemTemp.createTemp(
    'relay_startup_',
  );
  addTearDown(() => folder.delete(recursive: true));
  return folder;
}

List<String> backupsBeside(String databasePath) => <String>[
  for (final FileSystemEntity entity in Directory(
    p.dirname(databasePath),
  ).listSync())
    if (p.basename(entity.path).startsWith('${p.basename(databasePath)}.bak-'))
      p.basename(entity.path),
];

void main() {
  test('an empty data directory is migrated and reports healthy', () async {
    final Directory scratch = await scratchFolder();
    final String data = p.join(scratch.path, 'fresh', 'relay');
    expect(Directory(data).existsSync(), isFalse);

    final RelayHarness harness = await RelayHarness.start(dataDirectory: data);
    addTearDown(harness.dispose);

    expect(File(harness.databasePath).existsSync(), isTrue);
    expect(
      <String>[
        for (final Row row in harness.database.select(
          'SELECT name FROM schema_migrations ORDER BY name',
        ))
          row['name'] as String,
      ],
      <String>[
        for (final Migration migration in loadMigrations(
          harness.migrationsDirectory,
        ))
          migration.name,
      ],
    );
    final Set<String> tables = <String>{
      for (final Row row in harness.database.select(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      ))
        row['name'] as String,
    };
    expect(tables, containsAll(relayTables));
    expect(decodeBase64Url(harness.database.generation()), hasLength(16));
    expect(backupsBeside(harness.databasePath), isEmpty);

    final http.Response healthy = await harness.send(SyncRoutes.health);
    expect(healthy.statusCode, HttpStatus.ok);

    Process.runSync('chmod', <String>['555', harness.mediaDirectory]);
    addTearDown(
      () => Process.runSync('chmod', <String>['755', harness.mediaDirectory]),
    );
    final http.Response unwritable = await harness.send(SyncRoutes.health);
    expect(unwritable.statusCode, HttpStatus.serviceUnavailable);
    Process.runSync('chmod', <String>['755', harness.mediaDirectory]);
    expect((await harness.send(SyncRoutes.health)).statusCode, HttpStatus.ok);
  });

  test('a pending migration backs up a non-empty database first', () async {
    final Directory scratch = await scratchFolder();
    final Directory migrations = Directory(p.join(scratch.path, 'migrations'))
      ..createSync();
    final List<Migration> all = loadMigrations(defaultMigrationsDirectory());
    for (final Migration migration in all.take(all.length - 1)) {
      File(p.join(migrations.path, migration.name))
          .writeAsStringSync(migration.sql);
    }
    final RelayHarness harness = await RelayHarness.start(
      dataDirectory: p.join(scratch.path, 'data'),
      migrationsDirectory: migrations.path,
    );
    addTearDown(harness.dispose);
    final TestAccount account = await harness.enrol();
    expect(backupsBeside(harness.databasePath), isEmpty);
    await harness.stop();

    File(p.join(migrations.path, all.last.name))
        .writeAsStringSync(all.last.sql);
    harness.advance(const Duration(hours: 1));
    await harness.boot();

    final List<String> backups = backupsBeside(harness.databasePath);
    expect(backups, <String>[
      'relay.sqlite3.bak-${backupTimestamp(harness.now)}',
    ]);
    expect(
      backups.single,
      matches(RegExp(r'^relay\.sqlite3\.bak-\d{8}T\d{6}Z$')),
    );
    final RelayDatabase backup = RelayDatabase.openCopy(
      p.join(p.dirname(harness.databasePath), backups.single),
      readOnly: true,
    );
    addTearDown(backup.close);
    expect(
      backup.count('SELECT count(*) FROM accounts WHERE id = ?', <Object?>[
        account.accountId,
      ]),
      1,
    );
    expect(
      backup.count(
        "SELECT count(*) FROM sqlite_master WHERE name = 'mailboxes'",
      ),
      0,
    );
    expect(
      backup.count('SELECT count(*) FROM schema_migrations'),
      all.length - 1,
    );
    expect(
      harness.database.count(
        "SELECT count(*) FROM sqlite_master WHERE name = 'mailboxes'",
      ),
      1,
    );
    expect(
      harness.database.count('SELECT count(*) FROM schema_migrations'),
      all.length,
    );

    harness.advance(const Duration(hours: 1));
    await harness.restart();
    expect(backupsBeside(harness.databasePath), hasLength(1));
  });

  test('a failing migration stops start-up with a non-zero exit', () async {
    final Directory scratch = await scratchFolder();
    final String databasePath = p.join(scratch.path, 'relay.sqlite3');
    final RelayDatabase seeded = RelayDatabase.open(databasePath);
    seeded.execute('CREATE TABLE accounts (id TEXT)');
    seeded.close();

    expect(
      () => migrate(
        databasePath: databasePath,
        migrationsDirectory: defaultMigrationsDirectory(),
        now: harnessStart,
      ),
      throwsA(isA<MigrationException>()),
    );

    final ProcessResult result = await Process.run(
      Platform.resolvedExecutable,
      <String>['run', 'bin/relay.dart'],
      workingDirectory: p.dirname(defaultMigrationsDirectory()),
      environment: <String, String>{
        RelayConfig.databaseVariable: databasePath,
        RelayConfig.mediaVariable: p.join(scratch.path, 'media'),
        RelayConfig.portVariable: '0',
      },
    );
    expect(result.exitCode, isNot(0));
    expect('${result.stderr}', contains('0001_accounts.sql'));
  }, timeout: const Timeout(Duration(minutes: 4)));
}
