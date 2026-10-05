import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:relay_server/relay_server.dart';
import 'package:relay_server/src/blobs.dart';
import 'package:sync_protocol/sync_protocol.dart';
import 'package:test/test.dart';

import 'support/relay_harness.dart';

void main() {
  Future<RelayHarness> startHarness() async {
    final RelayHarness harness = await RelayHarness.start();
    addTearDown(harness.dispose);
    return harness;
  }

  Future<({TestAccount account, SignedIn mac, String name})> journalWithBlob(
    RelayHarness harness,
  ) async {
    final TestAccount account = await harness.enrol();
    final SignedIn mac = await harness.signIn(account.firstDevice);
    await harness.push(mac.session, <RecordPush>[harness.record('note-1')]);
    final String name = harness.blobName();
    await harness.uploadBlob(mac.session, name, harness.randomOpaque(1500));
    return (account: account, mac: mac, name: name);
  }

  void lockShard(RelayHarness harness, String accountId, String name) {
    final String shard = p.dirname(
      blobPath(harness.mediaDirectory, accountId, name),
    );
    Process.runSync('chmod', <String>['555', shard]);
    addTearDown(
      () => Process.runSync('chmod', <String>[
        '-R',
        'u+w',
        harness.mediaDirectory,
      ]),
    );
  }

  int rowsOf(RelayHarness harness, String table, String accountId) =>
      harness.database.count(
        'SELECT count(*) FROM $table WHERE account_id = ?',
        <Object?>[accountId],
      );

  test(
    'erasing a journal commits even when its files cannot be deleted at once',
    () async {
      final RelayHarness harness = await startHarness();
      final (:TestAccount account, :SignedIn mac, :String name) =
          await journalWithBlob(harness);
      lockShard(harness, account.accountId, name);

      final http.Response erased = await harness.send(
        SyncRoutes.eraseJournal,
        credential: mac.session,
      );

      expect(erased.statusCode, HttpStatus.noContent);
      expect(rowsOf(harness, 'records', account.accountId), 0);
      expect(rowsOf(harness, 'blobs', account.accountId), 0);
      expect(
        harness.database.selectOne(
          'SELECT status FROM accounts WHERE id = ?',
          <Object?>[account.accountId],
        )!['status'],
        'erased',
      );
      expect(
        Directory(p.join(harness.mediaDirectory, account.accountId))
            .existsSync(),
        isFalse,
      );
      final Directory trashed = Directory(
        p.join(
          harness.mediaDirectory,
          '.trash',
          '${account.accountId}-${harness.now.millisecondsSinceEpoch}',
        ),
      );
      expect(trashed.existsSync(), isTrue);

      Process.runSync('chmod', <String>['-R', 'u+w', harness.mediaDirectory]);
      await harness.restart();

      expect(
        Directory(p.join(harness.mediaDirectory, '.trash')).existsSync(),
        isFalse,
      );
    },
  );

  test(
    'deleting an account commits even when its files cannot be deleted at once',
    () async {
      final RelayHarness harness = await startHarness();
      final (:TestAccount account, :SignedIn mac, :String name) =
          await journalWithBlob(harness);
      lockShard(harness, account.accountId, name);
      final StringBuffer err = StringBuffer();

      final int code = runAdminCommand(
        <String>['account', 'delete', account.accountId],
        config: harness.config,
        out: StringBuffer(),
        err: err,
        clock: harness.clock,
      );

      expect(code, exitOk, reason: '$err');
      expect(
        harness.database.count(
          'SELECT count(*) FROM accounts WHERE id = ?',
          <Object?>[account.accountId],
        ),
        0,
      );
      expect(rowsOf(harness, 'records', account.accountId), 0);
      expect(
        Directory(p.join(harness.mediaDirectory, account.accountId))
            .existsSync(),
        isFalse,
      );
      expect(
        (await harness.send(
          SyncRoutes.pullRecords,
          credential: mac.session,
        )).statusCode,
        SyncErrorCode.journalErased.httpStatus,
      );
    },
  );

  test('start-up clears leftover trash and orphaned folders', () async {
    final RelayHarness harness = await startHarness();
    final (:TestAccount account, :SignedIn mac, :String name) =
        await journalWithBlob(harness);
    final String media = harness.mediaDirectory;
    final File leftover = File(
      p.join(media, '.trash', '${newSyncId()}-1', 'ab', 'leftover'),
    )..createSync(recursive: true);
    final File orphanBlob = File(p.join(media, newSyncId(), 'cd', 'orphan'))
      ..createSync(recursive: true);
    final File orphanPart = File(p.join(stagingPath(media, newSyncId()), '0'))
      ..createSync(recursive: true);
    final String unfinished = newSyncId();
    expect(
      (await harness.putPart(
        mac.session,
        name: harness.blobName(),
        uploadId: unfinished,
        index: 0,
        blobSize: 2048,
        partSize: 1024,
        bytes: harness.randomOpaque(1024),
      )).statusCode,
      HttpStatus.ok,
    );

    await harness.restart();

    expect(leftover.parent.parent.parent.existsSync(), isFalse);
    expect(orphanBlob.parent.parent.existsSync(), isFalse);
    expect(orphanPart.parent.existsSync(), isFalse);
    expect(Directory(stagingPath(media, unfinished)).existsSync(), isTrue);
    expect(File(blobPath(media, account.accountId, name)).existsSync(), isTrue);
  });
}
