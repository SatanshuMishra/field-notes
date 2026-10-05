import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:relay_server/src/blobs.dart';
import 'package:relay_server/src/live.dart';
import 'package:sync_protocol/sync_protocol.dart';
import 'package:test/test.dart';

import 'support/relay_harness.dart';

void main() {
  late RelayHarness harness;

  setUp(() async {
    harness = await RelayHarness.start();
  });

  tearDown(() async {
    await harness.dispose();
  });

  EpochKeysResponse keysOf(http.Response response) =>
      EpochKeysResponse.fromJson(decodeJsonObject(response.body));

  List<String> deviceIds(http.Response response) => <String>[
    for (final DeviceInfo device in DeviceListResponse.fromJson(
      decodeJsonObject(response.body),
    ).devices)
      device.deviceId,
  ];

  int countFor(String table, String accountId) => harness.database.count(
    'SELECT count(*) FROM $table WHERE account_id = ?',
    <Object?>[accountId],
  );

  test('a removed device is refused and new epoch keys skip it', () async {
    final TestAccount account = await harness.enrol();
    final TestDevice mac = account.firstDevice;
    final TestDevice phone = harness.addDevice(account);
    final TestDevice tablet = harness.addDevice(account);
    final SignedIn macIn = await harness.signIn(mac);
    final SignedIn phoneIn = await harness.signIn(phone);
    final SignedIn tabletIn = await harness.signIn(tablet);
    final LiveClient tabletLive = await harness.openLive(tabletIn.token);
    final List<String> remaining = <String>[
      mac.recipient,
      phone.recipient,
      EpochKeyDelivery.recoveryRecipient,
    ];

    final List<http.Response> invalid = <http.Response>[
      await harness.removeDevice(
        macIn,
        tablet.deviceId,
        harness.rotation(
          signer: mac,
          epoch: 2,
          recipients: <String>[...remaining, tablet.recipient],
        ),
      ),
      await harness.removeDevice(
        macIn,
        tablet.deviceId,
        harness.rotation(signer: mac, epoch: 3, recipients: remaining),
      ),
      await harness.removeDevice(
        macIn,
        tablet.deviceId,
        harness.rotation(signer: phone, epoch: 2, recipients: remaining),
      ),
    ];
    for (final http.Response response in invalid) {
      expect(response.statusCode, HttpStatus.badRequest);
    }
    expect(
      (await harness.send(
        SyncRoutes.pullRecords,
        credential: tabletIn.session,
      )).statusCode,
      HttpStatus.ok,
    );

    final EpochRotation rotation = harness.rotation(
      signer: mac,
      epoch: 2,
      recipients: remaining,
    );
    final http.Response removed = await harness.removeDevice(
      macIn,
      tablet.deviceId,
      rotation,
    );
    expect(removed.statusCode, HttpStatus.noContent);

    final http.Response next = await harness.send(
      SyncRoutes.pullRecords,
      credential: tabletIn.session,
    );
    expect(next.statusCode, HttpStatus.unauthorized);
    expect(errorOf(next).code, SyncErrorCode.deviceRemoved);
    final http.Response pushed = await harness.send(
      SyncRoutes.pushRecords,
      credential: tabletIn.pass,
      body: PushRequest(changes: <RecordPush>[harness.record('note-1')]),
    );
    expect(errorOf(pushed).code, SyncErrorCode.deviceRemoved);
    final http.Response challenge = await harness.send(
      SyncRoutes.sessionChallenge,
      body: ChallengeRequest(deviceId: tablet.deviceId),
    );
    expect(challenge.statusCode, HttpStatus.unauthorized);
    expect(errorOf(challenge).code, SyncErrorCode.deviceRemoved);
    await tabletLive.closed.timeout(const Duration(seconds: 5));
    expect(tabletLive.closeCode, liveRevokedCode);

    expect(
      harness.database
          .select(
            'SELECT recipient FROM epoch_deliveries '
            'WHERE account_id = ? AND epoch = 2',
            <Object?>[account.accountId],
          )
          .map((row) => row['recipient'] as String),
      unorderedEquals(remaining),
    );
    final EpochKeysResponse phoneKeys = keysOf(
      await harness.send(SyncRoutes.keys, credential: phoneIn.session),
    );
    expect(phoneKeys.currentEpoch, 2);
    expect(phoneKeys.rotations.single.deliveries, <EpochKeyDelivery>[
      rotation.deliveries[1],
    ]);
    expect(
      deviceIds(
        await harness.send(SyncRoutes.devices, credential: macIn.session),
      ),
      <String>[mac.deviceId, phone.deviceId],
    );

    expect(
      (await harness.removeDevice(
        macIn,
        phone.deviceId,
        harness.rotation(
          signer: mac,
          epoch: 3,
          recipients: <String>[
            mac.recipient,
            EpochKeyDelivery.recoveryRecipient,
          ],
        ),
      )).statusCode,
      HttpStatus.noContent,
    );
    final http.Response last = await harness.removeDevice(
      macIn,
      mac.deviceId,
      harness.rotation(
        signer: mac,
        epoch: 4,
        recipients: <String>[EpochKeyDelivery.recoveryRecipient],
      ),
    );
    expect(last.statusCode, HttpStatus.badRequest);
    expect(
      (await harness.send(
        SyncRoutes.pullRecords,
        credential: macIn.session,
      )).statusCode,
      HttpStatus.ok,
    );
  });

  test(
    'erasing a journal deletes its data and answers journal_erased',
    () async {
      final TestAccount account = await harness.enrol();
      final TestDevice mac = account.firstDevice;
      final TestDevice phone = harness.addDevice(account);
      final TestDevice spare = harness.addDevice(account);
      final SignedIn macIn = await harness.signIn(mac);
      final SignedIn phoneIn = await harness.signIn(phone);
      final TestAccount stranger = await harness.enrol(note: 'Stranger');
      final SignedIn strangerIn = await harness.signIn(stranger.firstDevice);

      await harness.push(macIn.session, <RecordPush>[
        harness.record('note-1'),
        harness.record('note-2'),
      ]);
      final String name = harness.blobName();
      await harness.uploadBlob(macIn.session, name, harness.randomOpaque(1500));
      final String unfinished = newSyncId();
      await harness.putPart(
        macIn.session,
        name: harness.blobName(),
        uploadId: unfinished,
        index: 0,
        blobSize: 2048,
        partSize: 1024,
        bytes: harness.randomOpaque(1024),
      );
      expect(
        (await harness.removeDevice(
          macIn,
          spare.deviceId,
          harness.rotation(
            signer: mac,
            epoch: 2,
            recipients: <String>[
              mac.recipient,
              phone.recipient,
              EpochKeyDelivery.recoveryRecipient,
            ],
          ),
        )).statusCode,
        HttpStatus.noContent,
      );
      expect(
        (await harness.send(
          SyncRoutes.openPairing,
          credential: macIn.session,
          body: PairingOpenRequest(
            mailboxId: newSyncId(),
            tokenHash: mailboxTokenHash('pairing-secret'),
          ),
        )).statusCode,
        HttpStatus.ok,
      );
      final String strangerBlob = harness.blobName();
      final Uint8List strangerBytes = harness.randomOpaque(700);
      await harness.push(strangerIn.session, <RecordPush>[
        harness.record('their-note', epoch: 1),
      ]);
      await harness.uploadBlob(strangerIn.session, strangerBlob, strangerBytes);
      final Directory media = Directory(
        accountMediaPath(harness.mediaDirectory, account.accountId),
      );
      final Directory staging = Directory(
        stagingPath(harness.mediaDirectory, unfinished),
      );
      expect(media.existsSync(), isTrue);
      expect(staging.existsSync(), isTrue);
      for (final String table in <String>[
        'records',
        'blobs',
        'uploads',
        'epoch_rotations',
        'epoch_deliveries',
        'mailboxes',
      ]) {
        expect(countFor(table, account.accountId), greaterThan(0));
      }

      final http.Response erased = await harness.send(
        SyncRoutes.eraseJournal,
        credential: phoneIn.session,
      );

      expect(erased.statusCode, HttpStatus.noContent);
      for (final String table in <String>[
        'records',
        'account_seqs',
        'change_ids',
        'blobs',
        'uploads',
        'epoch_rotations',
        'epoch_deliveries',
        'mailboxes',
      ]) {
        expect(countFor(table, account.accountId), 0, reason: table);
      }
      expect(
        harness.database.count(
          'SELECT count(*) FROM upload_parts WHERE upload_id = ?',
          <Object?>[unfinished],
        ),
        0,
      );
      expect(
        harness.database.count(
          'SELECT count(*) FROM devices WHERE account_id = ? AND status != ?',
          <Object?>[account.accountId, 'erased'],
        ),
        0,
      );
      expect(
        harness.database.selectOne(
          'SELECT status FROM accounts WHERE id = ?',
          <Object?>[account.accountId],
        )!['status'],
        'erased',
      );
      expect(media.existsSync(), isFalse);
      expect(staging.existsSync(), isFalse);

      for (final SignedIn device in <SignedIn>[macIn, phoneIn]) {
        final http.Response refused = await harness.send(
          SyncRoutes.pullRecords,
          credential: device.session,
        );
        expect(refused.statusCode, SyncErrorCode.journalErased.httpStatus);
        expect(errorOf(refused).code, SyncErrorCode.journalErased);
      }
      final http.Response challenge = await harness.send(
        SyncRoutes.sessionChallenge,
        body: ChallengeRequest(deviceId: phone.deviceId),
      );
      expect(errorOf(challenge).code, SyncErrorCode.journalErased);

      final PullResponse theirs = await harness.pull(strangerIn.session);
      expect(
        theirs.states.map((RecordState state) => state.recordKey),
        <String>['their-note'],
      );
      expect(
        (await harness.send(
          SyncRoutes.downloadBlob,
          parameters: <String, Object>{SyncRoutes.nameParameter: strangerBlob},
          credential: strangerIn.session,
        )).bodyBytes,
        strangerBytes,
      );
    },
  );

  test(
    'a device that removed itself still has its certificate returned',
    () async {
      final TestAccount account = await harness.enrol();
      final TestDevice mac = account.firstDevice;
      final TestDevice phone = harness.addDevice(account);
      final SignedIn macIn = await harness.signIn(mac);
      final SignedIn phoneIn = await harness.signIn(phone);

      final http.Response removed = await harness.removeDevice(
        phoneIn,
        phone.deviceId,
        harness.rotation(
          signer: phone,
          epoch: 2,
          recipients: <String>[
            mac.recipient,
            EpochKeyDelivery.recoveryRecipient,
          ],
        ),
      );

      expect(removed.statusCode, HttpStatus.noContent);
      final EpochKeysResponse keys = keysOf(
        await harness.send(SyncRoutes.keys, credential: macIn.session),
      );
      expect(keys.rotations.single.signerDeviceId, phone.deviceId);
      final DeviceInfo signer = keys.devices.singleWhere(
        (DeviceInfo device) => device.deviceId == phone.deviceId,
      );
      expect(signer.certificate, phone.registration.certificate);
      expect(signer.signPublicKey, phone.signKeys.publicKey);
      expect(
        deviceIds(
          await harness.send(SyncRoutes.devices, credential: macIn.session),
        ),
        <String>[mac.deviceId],
      );
      expect(
        errorOf(
          await harness.send(
            SyncRoutes.pullRecords,
            credential: phoneIn.session,
          ),
        ).code,
        SyncErrorCode.deviceRemoved,
      );
    },
  );
}
