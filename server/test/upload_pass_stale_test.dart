import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:sync_protocol/sync_protocol.dart';
import 'package:test/test.dart';

import 'support/relay_harness.dart';

void main() {
  test(
    'a stale push through the upload pass returns no record state',
    () async {
      final RelayHarness harness = await RelayHarness.start();
      addTearDown(harness.dispose);
      final TestAccount account = await harness.enrol();
      final SignedIn mac = await harness.signIn(account.firstDevice);
      final Uint8List envelope = Uint8List.fromList(
        utf8.encode('the stored state the upload pass must never read'),
      );
      final PushResponse first = await harness.push(mac.session, <RecordPush>[
        harness.record('note-1', envelope: envelope),
      ]);
      expect(first.results.single.status, PushStatus.accepted);

      final http.Response throughPass = await harness.send(
        SyncRoutes.pushRecords,
        credential: mac.pass,
        body: PushRequest(changes: <RecordPush>[harness.record('note-1')]),
      );
      final PushResponse throughSession = await harness.push(
        mac.session,
        <RecordPush>[harness.record('note-1')],
      );

      expect(throughPass.statusCode, HttpStatus.ok);
      final RecordPushResult passResult = PushResponse.fromJson(
        decodeJsonObject(throughPass.body),
      ).results.single;
      expect(passResult.status, PushStatus.stale);
      expect(passResult.current, isNull);
      expect(passResult.seq, isNull);
      expect(throughPass.body, isNot(contains(encodeBase64Url(envelope))));
      final RecordPushResult sessionResult = throughSession.results.single;
      expect(sessionResult.status, PushStatus.stale);
      expect(sessionResult.current!.seq, 1);
      expect(sessionResult.current!.envelope, envelope);
    },
  );
}
