import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:relay_server/relay_server.dart';
import 'package:relay_server/src/auth.dart';
import 'package:relay_server/src/change_log.dart';
import 'package:relay_server/src/database.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sync_protocol/sync_protocol.dart';
import 'package:test/test.dart';

import '../support/relay_harness.dart';

typedef WriterJob = ({
  String databasePath,
  String accountId,
  String deviceId,
  SendPort progress,
  int count,
  Set<int> waitAfter,
});

const String resume = 'resume';
const String done = 'done';

Future<void> pushInBackground(WriterJob job) async {
  final ReceivePort signals = ReceivePort();
  final StreamIterator<Object?> resumes = StreamIterator<Object?>(signals);
  job.progress.send(signals.sendPort);
  final RelayDatabase database = RelayDatabase.open(
    job.databasePath,
    create: false,
  );
  final ChangeLog changeLog = ChangeLog(database, systemClock);
  final Caller caller = Caller(
    accountId: job.accountId,
    deviceId: job.deviceId,
    kind: CallerKind.session,
  );
  for (int index = 0; index < job.count; index++) {
    changeLog.push(
      caller,
      PushRequest(
        changes: <RecordPush>[
          RecordPush(
            recordKey: 'writer-$index',
            baseSeq: 0,
            changeId: newSyncId(),
            epoch: 1,
            envelope: Uint8List(256),
          ),
        ],
      ),
    );
    job.progress.send(index + 1);
    if (job.waitAfter.contains(index + 1)) {
      await resumes.moveNext();
    }
  }
  database.close();
  await resumes.cancel();
  job.progress.send(done);
}

Set<String> recordKeys(RelayDatabase database) => <String>{
  for (final Row row in database.select('SELECT record_key FROM records'))
    row['record_key'] as String,
};

List<String> namesIn(Directory folder) => <String>[
  for (final FileSystemEntity entity in folder.listSync())
    p.basename(entity.path),
];

Future<(RelayHarness, TestAccount, List<String>)> seededRelay() async {
  final RelayHarness harness = await RelayHarness.start();
  addTearDown(harness.dispose);
  final TestAccount account = await harness.enrol();
  final SignedIn me = await harness.signIn(account.firstDevice);
  await harness.push(me.session, <RecordPush>[
    harness.record('seed-0'),
    harness.record('seed-1'),
  ]);
  final List<String> names = <String>[harness.blobName(), harness.blobName()];
  for (final String name in names) {
    await harness.uploadBlob(me.session, name, harness.randomOpaque(900));
  }
  return (harness, account, names);
}

void main() {
  test('a snapshot taken during writes passes the integrity check', () async {
    final (RelayHarness harness, TestAccount account, List<String> names) =
        await seededRelay();
    final ReceivePort progress = ReceivePort();
    addTearDown(progress.close);
    final StreamIterator<Object?> updates = StreamIterator<Object?>(progress);
    addTearDown(updates.cancel);
    Future<void> reach(Object wanted) async {
      while (await updates.moveNext()) {
        final Object? update = updates.current;
        if (update is List) {
          fail('The writer failed: $update');
        }
        if (update == wanted) {
          return;
        }
      }
      fail('The writer stopped before $wanted');
    }

    await Isolate.spawn<WriterJob>(pushInBackground, (
      databasePath: harness.databasePath,
      accountId: account.accountId,
      deviceId: account.firstDevice.deviceId,
      progress: progress.sendPort,
      count: 400,
      waitAfter: <int>{50, 60},
    ), onError: progress.sendPort);
    expect(await updates.moveNext(), isTrue);
    final SendPort writer = updates.current! as SendPort;
    await reach(50);
    writer.send(resume);

    final SnapshotResult result = snapshotDatabase(
      databasePath: harness.databasePath,
      target: p.join(harness.root.path, 'backup', 'relay-2026-10-04.sqlite3'),
    );
    writer.send(resume);
    await reach(done);

    final RelayDatabase copy = RelayDatabase.openCopy(
      result.databasePath,
      readOnly: true,
    );
    addTearDown(copy.close);
    expect(copy.select('PRAGMA integrity_check').single.columnAt(0), 'ok');
    final Set<String> copied = recordKeys(copy);
    final Set<String> live = recordKeys(harness.database);
    expect(live, hasLength(402));
    expect(copied.length, greaterThanOrEqualTo(52));
    expect(copied.length, lessThan(live.length));
    expect(live, containsAll(copied));
    final List<ManifestEntry> manifest = readManifest(result.manifestPath);
    expect(<String>{
      for (final ManifestEntry entry in manifest)
        if (entry.isRecord) entry.key,
    }, copied);
    expect(<String>{
      for (final ManifestEntry entry in manifest)
        if (!entry.isRecord) entry.key,
    }, names.toSet());
    expect(
      manifest.every(
        (ManifestEntry entry) => entry.accountId == account.accountId,
      ),
      isTrue,
    );
    expect(result.records, copied.length);
    expect(result.blobs, 2);
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('the snapshot never includes wal or shm files', () async {
    final (RelayHarness harness, TestAccount _, List<String> _) =
        await seededRelay();
    expect(File('${harness.databasePath}-wal').existsSync(), isTrue);
    expect(File('${harness.databasePath}-shm').existsSync(), isTrue);
    final Directory folder = Directory(p.join(harness.root.path, 'backup'));
    final String target = p.join(folder.path, 'relay-2026-10-04.sqlite3');
    final StringBuffer out = StringBuffer();
    final StringBuffer err = StringBuffer();

    final int code = runBackupCommand(
      <String>['snapshot-db', '--to', target],
      config: harness.config,
      out: out,
      err: err,
    );

    expect(code, exitOk, reason: '$err');
    expect(
      namesIn(folder),
      unorderedEquals(<String>[
        'relay-2026-10-04.sqlite3',
        'relay-2026-10-04.sqlite3.manifest',
      ]),
    );
    expect(
      verifyCopy(
        databasePath: target,
        mediaDirectory: harness.mediaDirectory,
        manifestPath: manifestPathFor(target),
      ),
      isEmpty,
    );
    final StringBuffer again = StringBuffer();
    expect(
      runBackupCommand(
        <String>['snapshot-db', '--to', target],
        config: harness.config,
        out: StringBuffer(),
        err: again,
      ),
      exitFailure,
    );
    expect('$again', contains('already exists'));
    expect(
      namesIn(folder),
      unorderedEquals(<String>[
        'relay-2026-10-04.sqlite3',
        'relay-2026-10-04.sqlite3.manifest',
      ]),
    );
  });
}
