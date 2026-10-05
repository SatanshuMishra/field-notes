import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:relay_server/src/auth.dart';
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

  void expectForbidden(http.Response response, SyncRoute route) {
    expect(response.statusCode, HttpStatus.forbidden, reason: '$route');
    if (route.method != 'HEAD') {
      expect(errorOf(response).code, SyncErrorCode.forbidden, reason: '$route');
      expect(
        decodeJsonObject(response.body).keys,
        unorderedEquals(<String>[protocolVersionField, 'code', 'message']),
      );
    }
  }

  test('an upload pass pushes and uploads parts but reads nothing', () async {
    final TestAccount account = await harness.enrol();
    final TestDevice phone = harness.addDevice(account);
    final SignedIn mac = await harness.signIn(account.firstDevice);
    final SignedIn phoneIn = await harness.signIn(phone);
    final LiveClient macLive = await harness.openLive(mac.token);
    final LiveClient phoneLive = await harness.openLive(phoneIn.token);
    final String name = harness.blobName();
    final List<int> blob = harness.randomOpaque(600);

    final PushResponse pushed = await harness.push(mac.pass, <RecordPush>[
      harness.record('note-1'),
    ]);
    final http.Response uploaded = await harness.putPart(
      mac.pass,
      name: name,
      uploadId: newSyncId(),
      index: 0,
      blobSize: blob.length,
      partSize: 1024,
      bytes: blob,
    );

    expect(pushed.results.single.status, PushStatus.accepted);
    expect(await phoneLive.next(), const LiveNudge(latestSeq: 1));
    macLive.send(const LivePing());
    expect(await macLive.next(), const LivePong());
    expect(uploaded.statusCode, HttpStatus.ok);
    expect(
      UploadStatusResponse.fromJson(decodeJsonObject(uploaded.body)).assembled,
      isTrue,
    );
    expect(
      (await harness.send(
        SyncRoutes.downloadBlob,
        parameters: <String, Object>{SyncRoutes.nameParameter: name},
        credential: mac.session,
      )).bodyBytes,
      blob,
    );

    const List<SyncRoute> reads = <SyncRoute>[
      SyncRoutes.pullRecords,
      SyncRoutes.downloadBlob,
      SyncRoutes.keys,
      SyncRoutes.devices,
    ];
    for (final SyncRoute route in SyncRoutes.all) {
      if (uploadPassRoutes.contains(route)) {
        continue;
      }
      final http.Response response = await harness.send(
        route,
        parameters: <String, Object>{
          for (final String parameter in route.parameterNames)
            parameter: switch (parameter) {
              SyncRoutes.nameParameter => name,
              SyncRoutes.indexParameter => 0,
              SyncRoutes.deviceIdParameter => phone.deviceId,
              _ => newSyncId(),
            },
        },
        credential: mac.pass,
      );
      expectForbidden(response, route);
      if (reads.contains(route)) {
        expect(response.bodyBytes, isNot(blob));
        expect(response.body, isNot(contains('states')));
        expect(response.body, isNot(contains('devices')));
      }
    }
    expect(uploadPassRoutes, <SyncRoute>[
      SyncRoutes.pushRecords,
      SyncRoutes.uploadPart,
    ]);
  });

  test('an expired upload pass is refused', () async {
    final TestAccount account = await harness.enrol();
    final SignedIn mac = await harness.signIn(account.firstDevice);
    final String name = harness.blobName();

    harness.advance(uploadPassLifetime - const Duration(seconds: 1));
    expect(
      (await harness.send(
        SyncRoutes.pullRecords,
        credential: mac.session,
      )).statusCode,
      HttpStatus.unauthorized,
    );
    final PushResponse stillValid = await harness.push(mac.pass, <RecordPush>[
      harness.record('note-1'),
    ]);
    expect(stillValid.results.single.status, PushStatus.accepted);
    harness.advance(const Duration(seconds: 1));

    final http.Response push = await harness.send(
      SyncRoutes.pushRecords,
      credential: mac.pass,
      body: PushRequest(changes: <RecordPush>[harness.record('note-2')]),
    );
    final http.Response part = await harness.putPart(
      mac.pass,
      name: name,
      uploadId: newSyncId(),
      index: 0,
      blobSize: 10,
      partSize: 1024,
      bytes: harness.randomOpaque(10),
    );

    for (final http.Response response in <http.Response>[push, part]) {
      expect(response.statusCode, HttpStatus.unauthorized);
      expect(errorOf(response).code, SyncErrorCode.unauthorized);
    }
    expect(harness.database.count('SELECT count(*) FROM records'), 1);
    expect(harness.database.count('SELECT count(*) FROM uploads'), 0);
  });
}
