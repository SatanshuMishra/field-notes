import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:relay_server/src/accounts.dart';
import 'package:relay_server/src/logging.dart';
import 'package:sync_protocol/sync_protocol.dart';
import 'package:test/test.dart';

import 'support/relay_harness.dart';

void main() {
  test('log lines hold only the allowed fields', () async {
    final RelayHarness harness = await RelayHarness.start();
    addTearDown(harness.dispose);
    final Set<String> patterns = <String>{
      for (final SyncRoute route in SyncRoutes.all) route.pattern,
      unmatchedRoute,
    };
    int requests = 0;
    Future<http.Response> counted(Future<http.Response> request) {
      requests++;
      return request;
    }

    const String note = 'Private note for Alex';
    final CreatedInvite invite = harness.createInvite(note);
    final TestKeys certifying = harness.signKeys();
    final TestDevice device = harness.newDevice(certifying);
    final http.Response redeemed = await counted(
      harness.send(
        SyncRoutes.redeemInvite,
        body: harness.redeemRequest(
          invite.code,
          certifyingKeys: certifying,
          device: device,
          recoverySignKeys: harness.signKeys(),
          recoveryBoxPublicKey: harness.sodium.crypto.box.keyPair().publicKey,
          recoveryEpochOneCopy: harness.randomOpaque(72),
        ),
      ),
    );
    expect(redeemed.statusCode, HttpStatus.ok);
    final String accountId = InviteRedeemResponse.fromJson(
      decodeJsonObject(redeemed.body),
    ).accountId;

    requests++;
    final ChallengeResponse challenge = await harness.challenge(device);
    final SessionRequest sessionRequest = harness.sessionRequest(
      device,
      challenge,
    );
    final http.Response session = await counted(
      harness.send(SyncRoutes.session, body: sessionRequest),
    );
    final SessionResponse signedIn = SessionResponse.fromJson(
      decodeJsonObject(session.body),
    );
    final AuthCredential credential = AuthCredential(
      AuthScheme.session,
      signedIn.token,
    );

    final Uint8List envelope = Uint8List.fromList(
      utf8.encode('secret journal text that must never be logged'),
    );
    await counted(
      harness.send(
        SyncRoutes.pushRecords,
        credential: credential,
        body: PushRequest(
          changes: <RecordPush>[
            harness.record('record-key-logged', envelope: envelope),
          ],
        ),
      ),
    );
    await counted(
      harness.send(
        SyncRoutes.pushRecords,
        credential: AuthCredential(AuthScheme.uploadPass, signedIn.uploadPass),
        body: PushRequest(changes: <RecordPush>[harness.record('second-key')]),
      ),
    );
    await counted(harness.send(SyncRoutes.pullRecords, credential: credential));

    final String name = harness.blobName();
    final String uploadId = newSyncId();
    final List<int> blob = utf8.encode('secret photo bytes that must stay out');
    await counted(
      harness.putPart(
        credential,
        name: name,
        uploadId: uploadId,
        index: 0,
        blobSize: blob.length,
        partSize: 1024,
        bytes: blob,
      ),
    );
    final Map<String, Object> blobParameters = <String, Object>{
      SyncRoutes.nameParameter: name,
    };
    await counted(
      harness.send(
        SyncRoutes.blobExists,
        parameters: blobParameters,
        credential: credential,
      ),
    );
    final http.Response downloaded = await counted(
      harness.send(
        SyncRoutes.downloadBlob,
        parameters: blobParameters,
        credential: credential,
      ),
    );
    expect(downloaded.bodyBytes, blob);
    await counted(
      harness.send(
        SyncRoutes.uploadStatus,
        parameters: <String, Object>{
          SyncRoutes.nameParameter: name,
          SyncRoutes.uploadIdParameter: uploadId,
        },
        credential: credential,
      ),
    );
    await counted(
      harness.send(
        SyncRoutes.reportReferencedBlobs,
        credential: credential,
        body: BlobNamesRequest(names: <String>[name]),
      ),
    );
    await counted(harness.send(SyncRoutes.keys, credential: credential));
    await counted(harness.send(SyncRoutes.devices, credential: credential));
    await counted(harness.send(SyncRoutes.health));
    await counted(
      harness.send(const SyncRoute('GET', '/v1/not-a-route/secret-path')),
    );
    await counted(
      harness.send(
        SyncRoutes.pullRecords,
        credential: AuthCredential(AuthScheme.session, '${signedIn.token}x'),
      ),
    );
    requests++;
    final LiveClient live = await harness.openLive(signedIn.token);
    await live.close();

    final List<String> forbidden = <String>[
      invite.code,
      normalizeInviteCode(invite.code),
      note,
      'Private note',
      signedIn.token,
      signedIn.uploadPass,
      signedIn.token.split('.').last,
      signedIn.uploadPass.split('.').last,
      challenge.nonce,
      encodeBase64Url(sessionRequest.signature),
      encodeBase64Url(envelope),
      'secret',
      'record-key-logged',
      name,
      encodeBase64Url(blob),
      'Bearer',
      'Upload',
      'Dart/',
      'application/json',
      SyncHeaders.protocol,
    ];
    expect(harness.logLines, hasLength(requests));
    for (final String line in harness.logLines) {
      expect(line, isNot(contains('\n')));
      final Object? decoded = jsonDecode(line);
      expect(decoded, isA<Map<String, Object?>>());
      final Map<String, Object?> fields = decoded! as Map<String, Object?>;
      expect(fields.keys.toSet(), logFields.toSet());
      expect(DateTime.tryParse(fields['ts']! as String), isNotNull);
      expect(patterns, contains(fields['route']));
      expect(fields['bytes'], isA<int>());
      expect(fields['status'], isA<int>());
      expect(fields['ms'], isA<int>());
      for (final String key in <String>['account', 'device']) {
        final Object? value = fields[key];
        expect(value == null || (value is String && isSyncId(value)), isTrue);
      }
      for (final String secret in forbidden) {
        expect(line, isNot(contains(secret)));
      }
    }
    final List<Map<String, Object?>> parsed = <Map<String, Object?>>[
      for (final String line in harness.logLines)
        jsonDecode(line) as Map<String, Object?>,
    ];
    final Map<String, Object?> push = parsed.firstWhere(
      (Map<String, Object?> fields) =>
          fields['route'] == SyncRoutes.pushRecords.pattern,
    );
    expect(push['account'], accountId);
    expect(push['device'], device.deviceId);
    expect(push['status'], HttpStatus.ok);
    expect(push['bytes'] as int, greaterThan(envelope.length));
    expect(
      parsed.map((Map<String, Object?> fields) => fields['route']),
      containsAll(<String>[
        SyncRoutes.uploadPart.pattern,
        SyncRoutes.downloadBlob.pattern,
        SyncRoutes.live.pattern,
        unmatchedRoute,
      ]),
    );
    expect(
      parsed.singleWhere(
        (Map<String, Object?> fields) =>
            fields['route'] == SyncRoutes.live.pattern,
      )['status'],
      HttpStatus.switchingProtocols,
    );
  });
}
