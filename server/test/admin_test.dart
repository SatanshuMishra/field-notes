import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:relay_server/relay_server.dart';
import 'package:relay_server/src/accounts.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sync_protocol/sync_protocol.dart';
import 'package:test/test.dart';

import 'support/relay_harness.dart';

typedef AdminRun = ({int code, String out, String err});

List<List<String>> rowsOf(String output) => <List<String>>[
  for (final String line in output.trim().split('\n')) line.split('\t'),
];

void main() {
  late RelayHarness harness;

  setUp(() async {
    harness = await RelayHarness.start();
  });

  tearDown(() async {
    await harness.dispose();
  });

  AdminRun admin(List<String> arguments) {
    final StringBuffer out = StringBuffer();
    final StringBuffer err = StringBuffer();
    final int code = runAdminCommand(
      arguments,
      config: harness.config,
      out: out,
      err: err,
      clock: harness.clock,
    );
    return (code: code, out: '$out', err: '$err');
  }

  String statusOf(TestAccount account) =>
      harness.database.selectOne(
            'SELECT status FROM accounts WHERE id = ?',
            <Object?>[account.accountId],
          )!['status']
          as String;

  Map<String, Object> parametersFor(SyncRoute route, String deviceId) =>
      <String, Object>{
        for (final String parameter in route.parameterNames)
          parameter: switch (parameter) {
            SyncRoutes.nameParameter => harness.blobName(),
            SyncRoutes.indexParameter => 0,
            SyncRoutes.deviceIdParameter => deviceId,
            _ => newSyncId(),
          },
      };

  test('admin commands manage invites and accounts', () async {
    final AdminRun created = admin(<String>[
      'invite',
      'create',
      '--note',
      'Alex',
    ]);
    expect(created.code, exitOk);
    final Map<String, String> invite = <String, String>{
      for (final List<String> row in rowsOf(created.out)) row[0]: row[1],
    };
    expect(invite.keys, <String>['id', 'code', 'expires']);
    expect(
      invite['expires'],
      harness.now.add(inviteLifetime).toIso8601String(),
    );
    final Row stored = harness.database.selectOne(
      'SELECT note, code_hash FROM invites WHERE id = ?',
      <Object?>[invite['id']],
    )!;
    expect(stored['note'], 'Alex');
    expect(stored['code_hash'], inviteCodeHash(invite['code']!));

    final List<List<String>> listed = rowsOf(
      admin(<String>['invite', 'list']).out,
    );
    expect(listed.first, <String>['id', 'note', 'created', 'expires', 'state']);
    expect(listed[1], <String>[
      invite['id']!,
      'Alex',
      harness.now.toIso8601String(),
      invite['expires']!,
      'open',
    ]);

    expect(admin(<String>['invite', 'revoke', invite['id']!]).code, exitOk);
    expect(
      harness.database.selectOne(
        'SELECT revoked_at FROM invites WHERE id = ?',
        <Object?>[invite['id']],
      )!['revoked_at'],
      isNotNull,
    );
    expect(rowsOf(admin(<String>['invite', 'list']).out)[1].last, 'revoked');
    expect(
      admin(<String>['invite', 'revoke', invite['id']!]).code,
      exitFailure,
    );

    final TestAccount account = await harness.enrol(note: 'Sam');
    final SignedIn sam = await harness.signIn(account.firstDevice);
    await harness.push(sam.session, <RecordPush>[
      harness.record('note-1', envelope: List<int>.filled(100, 7)),
    ]);
    final String name = harness.blobName();
    await harness.uploadBlob(sam.session, name, harness.randomOpaque(300));

    final AdminRun accounts = admin(<String>['account', 'list']);

    expect(accounts.code, exitOk);
    final List<List<String>> table = rowsOf(accounts.out);
    expect(table.first, <String>[
      'id',
      'note',
      'status',
      'devices',
      'bytes',
      'last_seen',
    ]);
    expect(table.skip(1).toList(), <List<String>>[
      <String>[
        account.accountId,
        'Sam',
        'active',
        '1',
        '400',
        harness.now.toIso8601String(),
      ],
    ]);
    for (final List<int> secret in <List<int>>[
      account.firstDevice.signKeys.publicKey,
      account.firstDevice.boxPublicKey,
      account.firstDevice.registration.certificate,
      account.firstDevice.registration.encryptedName,
      account.recoverySignKeys.publicKey,
      account.recoveryBoxPublicKey,
      account.recoveryEpochOneCopy,
    ]) {
      expect(accounts.out, isNot(contains(encodeBase64Url(secret))));
    }
    expect(accounts.out, isNot(contains(account.firstDevice.deviceId)));
    expect(accounts.out, isNot(contains(name)));

    expect(
      admin(<String>['account', 'suspend', account.accountId]).code,
      exitOk,
    );
    expect(statusOf(account), 'suspended');
    expect(rowsOf(admin(<String>['account', 'list']).out)[1][2], 'suspended');
    expect(
      admin(<String>['account', 'resume', account.accountId]).code,
      exitOk,
    );
    expect(statusOf(account), 'active');

    final File file = File(
      blobPath(harness.mediaDirectory, account.accountId, name),
    );
    expect(file.existsSync(), isTrue);

    expect(
      admin(<String>['account', 'delete', account.accountId]).code,
      exitOk,
    );

    expect(
      harness.database.count(
        'SELECT count(*) FROM accounts WHERE id = ?',
        <Object?>[account.accountId],
      ),
      0,
    );
    for (final String table in <String>['records', 'blobs', 'uploads']) {
      expect(
        harness.database.count(
          'SELECT count(*) FROM $table WHERE account_id = ?',
          <Object?>[account.accountId],
        ),
        0,
        reason: table,
      );
    }
    expect(file.existsSync(), isFalse);
    expect(
      harness.database.count(
        'SELECT count(*) FROM devices WHERE account_id = ? AND status != ?',
        <Object?>[account.accountId, 'erased'],
      ),
      0,
    );
    expect(rowsOf(admin(<String>['account', 'list']).out), hasLength(1));
    expect(
      admin(<String>['account', 'delete', account.accountId]).code,
      exitFailure,
    );
    expect(admin(<String>['account', 'suspend', 'missing']).code, exitFailure);
    expect(admin(<String>['invite', 'create']).code, exitUsage);
    expect(admin(<String>['nonsense']).code, exitUsage);
  });

  test("a suspended account's devices are refused", () async {
    final TestAccount account = await harness.enrol();
    final TestDevice phone = harness.addDevice(account);
    final SignedIn mac = await harness.signIn(account.firstDevice);

    expect(
      admin(<String>['account', 'suspend', account.accountId]).code,
      exitOk,
    );

    final Set<SyncRoute> unauthenticated = <SyncRoute>{
      SyncRoutes.redeemInvite,
      SyncRoutes.sessionChallenge,
      SyncRoutes.session,
      SyncRoutes.restoreChallenge,
      SyncRoutes.restore,
      SyncRoutes.registerRestoredDevice,
      SyncRoutes.joinPairing,
      SyncRoutes.health,
    };
    for (final SyncRoute route in SyncRoutes.all) {
      if (unauthenticated.contains(route)) {
        continue;
      }
      final http.Response response = await harness.send(
        route,
        parameters: parametersFor(route, phone.deviceId),
        credential: mac.session,
      );
      expect(response.statusCode, HttpStatus.forbidden, reason: '$route');
      if (route.method != 'HEAD') {
        expect(
          errorOf(response).code,
          SyncErrorCode.suspended,
          reason: '$route',
        );
      }
    }
    for (final SyncRoute route in <SyncRoute>[
      SyncRoutes.pushRecords,
      SyncRoutes.uploadPart,
    ]) {
      final http.Response response = await harness.send(
        route,
        parameters: parametersFor(route, phone.deviceId),
        credential: mac.pass,
      );
      expect(errorOf(response).code, SyncErrorCode.suspended, reason: '$route');
    }
    final http.Response challenge = await harness.send(
      SyncRoutes.sessionChallenge,
      body: ChallengeRequest(deviceId: phone.deviceId),
    );
    expect(challenge.statusCode, HttpStatus.forbidden);
    expect(errorOf(challenge).code, SyncErrorCode.suspended);
    final http.Response restore = await harness.send(
      SyncRoutes.restoreChallenge,
      body: RestoreChallengeRequest(
        recoverySignPublicKey: account.recoverySignKeys.publicKey,
      ),
    );
    expect(errorOf(restore).code, SyncErrorCode.suspended);
    await expectLater(
      harness.openLive(mac.token),
      throwsA(isA<WebSocketException>()),
    );

    expect(
      admin(<String>['account', 'resume', account.accountId]).code,
      exitOk,
    );
    expect(
      (await harness.send(
        SyncRoutes.pullRecords,
        credential: mac.session,
      )).statusCode,
      HttpStatus.ok,
    );
  });

  test('marking the relay restored changes its generation', () async {
    final TestAccount account = await harness.enrol();
    final SignedIn before = await harness.signIn(account.firstDevice);
    final String oldGeneration = before.response.generation;
    expect((await harness.pull(before.session)).generation, oldGeneration);
    await harness.stop();

    final AdminRun marked = admin(<String>['mark-restored']);

    expect(marked.code, exitOk);
    final List<String> generationLine = rowsOf(marked.out).first;
    expect(generationLine.first, 'generation');
    final String newGeneration = generationLine.last;
    expect(newGeneration, isNot(oldGeneration));
    expect(decodeBase64Url(newGeneration), hasLength(16));
    await harness.boot();
    expect(harness.database.count('SELECT count(*) FROM sessions'), 0);

    final http.Response oldSession = await harness.send(
      SyncRoutes.pullRecords,
      credential: before.session,
    );
    final http.Response oldPass = await harness.send(
      SyncRoutes.pushRecords,
      credential: before.pass,
      body: PushRequest(changes: <RecordPush>[harness.record('note-1')]),
    );
    expect(oldSession.statusCode, HttpStatus.unauthorized);
    expect(oldPass.statusCode, HttpStatus.unauthorized);
    final SignedIn after = await harness.signIn(account.firstDevice);
    expect(after.response.generation, newGeneration);
    expect((await harness.pull(after.session)).generation, newGeneration);

    await harness.stop();
    final String exported = markRestored(harness.config);
    await harness.boot();
    expect(exported, isNot(newGeneration));
    expect(
      (await harness.signIn(account.firstDevice)).response.generation,
      exported,
    );
  });
}
