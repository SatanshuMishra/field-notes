import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:relay_server/relay_server.dart';
import 'package:relay_server/src/blobs.dart';
import 'package:sync_protocol/sync_protocol.dart';
import 'package:test/test.dart';

import '../support/relay_harness.dart';

void copyTree(Directory source, Directory target) {
  for (final FileSystemEntity entity in source.listSync(recursive: true)) {
    final String relative = p.relative(entity.path, from: source.path);
    if (p.split(relative).contains(stagingFolderName)) {
      continue;
    }
    final String destination = p.join(target.path, relative);
    if (entity is Directory) {
      Directory(destination).createSync(recursive: true);
    } else if (entity is File) {
      Directory(p.dirname(destination)).createSync(recursive: true);
      entity.copySync(destination);
    }
  }
}

void main() {
  test('a good copy passes and a copy missing a blob fails', () async {
    final RelayHarness harness = await RelayHarness.start();
    addTearDown(harness.dispose);
    final TestAccount account = await harness.enrol();
    final SignedIn me = await harness.signIn(account.firstDevice);
    await harness.push(me.session, <RecordPush>[
      harness.record('note-0'),
      harness.record('note-1'),
      harness.record('note-2'),
    ]);
    final List<String> names = <String>[harness.blobName(), harness.blobName()];
    for (final String name in names) {
      await harness.uploadBlob(me.session, name, harness.randomOpaque(1300));
    }
    final Directory nas = Directory(p.join(harness.root.path, 'nas'));
    final String database = p.join(
      nas.path,
      'backup',
      'relay-2026-10-01.sqlite3',
    );
    final SnapshotResult snapshot = snapshotDatabase(
      databasePath: harness.databasePath,
      target: database,
    );
    final String media = p.join(nas.path, 'media');
    copyTree(Directory(harness.mediaDirectory), Directory(media));

    ({int code, String out, String err}) verify() {
      final StringBuffer out = StringBuffer();
      final StringBuffer err = StringBuffer();
      final int code = runBackupCommand(
        <String>[
          'verify-copy',
          '--db',
          database,
          '--media',
          media,
          '--manifest',
          snapshot.manifestPath,
        ],
        config: harness.config,
        out: out,
        err: err,
      );
      return (code: code, out: '$out', err: '$err');
    }

    final ({int code, String out, String err}) good = verify();
    expect(good.code, exitOk, reason: good.err);
    expect(good.err, isEmpty);
    expect(snapshot.records, 3);
    expect(snapshot.blobs, 2);

    File(blobPath(media, account.accountId, names.first)).deleteSync();
    final ({int code, String out, String err}) missing = verify();

    expect(missing.code, exitFailure);
    expect(
      missing.err,
      contains('missing blob ${account.accountId}/${names.first}'),
    );
    expect(missing.err, isNot(contains(names.last)));

    File(database).writeAsBytesSync(List<int>.filled(8192, 0));
    expect(verify().code, exitFailure);
  });
}
