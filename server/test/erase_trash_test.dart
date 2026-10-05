import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:relay_server/relay_server.dart';
import 'package:relay_server/src/blobs.dart';
import 'package:sync_protocol/sync_protocol.dart';
import 'package:test/test.dart';

import 'support/relay_harness.dart';

final bool runningAsRoot =
    '${Process.runSync('id', <String>['-u']).stdout}'.trim() == '0';

const String rootSkip = 'chmod does not stop root from deleting files';

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
    skip: runningAsRoot ? rootSkip : false,
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
    skip: runningAsRoot ? rootSkip : false,
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
    expect(orphanBlob.parent.parent.existsSync(), isTrue);
    expect(orphanPart.parent.existsSync(), isFalse);
    expect(Directory(stagingPath(media, unfinished)).existsSync(), isTrue);
    expect(File(blobPath(media, account.accountId, name)).existsSync(), isTrue);
  });

  test('starting on an empty database deletes no media', () async {
    final Directory scratch = await Directory.systemTemp.createTemp(
      'relay_empty_database_',
    );
    addTearDown(() => scratch.delete(recursive: true));
    final String data = p.join(scratch.path, 'data');
    final String media = p.join(data, 'media');
    final List<File> kept = <File>[
      File(p.join(media, newSyncId(), 'ab', 'first-account-blob')),
      File(p.join(media, newSyncId(), 'cd', 'second-account-blob')),
      File(p.join(stagingPath(media, newSyncId()), '0')),
    ];
    for (final File file in kept) {
      file
        ..createSync(recursive: true)
        ..writeAsStringSync('kept');
    }
    expect(File(p.join(data, 'relay.sqlite3')).existsSync(), isFalse);

    final RelayHarness harness = await RelayHarness.start(dataDirectory: data);
    addTearDown(harness.dispose);

    expect(harness.database.count('SELECT count(*) FROM accounts'), 0);
    for (final File file in kept) {
      expect(file.existsSync(), isTrue, reason: file.path);
      expect(file.readAsStringSync(), 'kept', reason: file.path);
    }
  });

  test(
    "deleted and erased accounts' leftover media is cleared at start-up",
    () async {
      final RelayHarness harness = await startHarness();
      final TestAccount erasedAccount = await harness.enrol(note: 'Erased');
      final TestAccount deletedAccount = await harness.enrol(note: 'Deleted');
      final TestAccount liveAccount = await harness.enrol(note: 'Live');
      final SignedIn erasedIn = await harness.signIn(erasedAccount.firstDevice);
      final SignedIn liveIn = await harness.signIn(liveAccount.firstDevice);
      final String liveName = harness.blobName();
      await harness.uploadBlob(
        liveIn.session,
        liveName,
        harness.randomOpaque(1500),
      );
      expect(
        (await harness.send(
          SyncRoutes.eraseJournal,
          credential: erasedIn.session,
        )).statusCode,
        HttpStatus.noContent,
      );
      expect(
        runAdminCommand(
          <String>['account', 'delete', deletedAccount.accountId],
          config: harness.config,
          out: StringBuffer(),
          err: StringBuffer(),
          clock: harness.clock,
        ),
        exitOk,
      );
      expect(
        harness.database.count(
          'SELECT count(*) FROM deleted_accounts WHERE id = ?',
          <Object?>[deletedAccount.accountId],
        ),
        1,
      );
      final String media = harness.mediaDirectory;
      final String unknownAccount = newSyncId();
      final List<Directory> leftovers = <Directory>[
        for (final String accountId in <String>[
          erasedAccount.accountId,
          deletedAccount.accountId,
        ])
          Directory(p.join(media, accountId)),
      ];
      for (final Directory folder in leftovers) {
        File(p.join(folder.path, 'ab', 'leftover')).createSync(recursive: true);
      }
      final File unknown = File(p.join(media, unknownAccount, 'ef', 'kept'))
        ..createSync(recursive: true);
      harness.logLines.clear();

      await harness.restart();

      for (final Directory folder in leftovers) {
        expect(folder.existsSync(), isFalse, reason: folder.path);
      }
      expect(
        File(blobPath(media, liveAccount.accountId, liveName)).existsSync(),
        isTrue,
      );
      expect(unknown.existsSync(), isTrue);
      final List<Map<String, Object?>> cleared = <Map<String, Object?>>[
        for (final String line in harness.logLines)
          if ((jsonDecode(line) as Map<String, Object?>)['event'] ==
              'leftovers_cleared')
            jsonDecode(line) as Map<String, Object?>,
      ];
      expect(cleared, hasLength(1));
      expect(cleared.single['erased_accounts'], 1);
      expect(cleared.single['deleted_accounts'], 1);
      for (final String line in harness.logLines) {
        for (final String accountId in <String>[
          erasedAccount.accountId,
          deletedAccount.accountId,
          liveAccount.accountId,
          unknownAccount,
        ]) {
          expect(line, isNot(contains(accountId)));
        }
      }
    },
  );
}
