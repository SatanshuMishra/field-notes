import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:sync_protocol/sync_protocol.dart';
import 'package:test/test.dart';

import 'support/relay_harness.dart';

void main() {
  late RelayHarness harness;
  late TestAccount account;
  late SignedIn owner;

  setUp(() async {
    harness = await RelayHarness.start();
    account = await harness.enrol();
    owner = await harness.signIn(account.firstDevice);
  });

  tearDown(() async {
    await harness.dispose();
  });

  String newToken() => encodeBase64Url(harness.randomOpaque(16));

  Map<String, Object> mailbox(String mailboxId) => <String, Object>{
    SyncRoutes.mailboxIdParameter: mailboxId,
  };

  Future<void> openMailbox(String mailboxId, String token) async {
    final http.Response response = await harness.send(
      SyncRoutes.openPairing,
      credential: owner.session,
      body: PairingOpenRequest(
        mailboxId: mailboxId,
        tokenHash: mailboxTokenHash(token),
      ),
    );
    expect(response.statusCode, HttpStatus.ok);
  }

  Future<void> pair(String mailboxId, String token, Uint8List bundle) async {
    final TestDevice newcomer = harness.newDevice(account.certifyingKeys);
    final http.Response joined = await harness.send(
      SyncRoutes.joinPairing,
      parameters: mailbox(mailboxId),
      credential: AuthCredential(AuthScheme.mailbox, token),
      body: PairingJoinRequest(
        device: newcomer.registration,
        authenticator: harness.randomOpaque(32),
      ),
    );
    expect(joined.statusCode, HttpStatus.ok);
    final http.Response completed = await harness.send(
      SyncRoutes.completePairing,
      parameters: mailbox(mailboxId),
      credential: owner.session,
      body: PairingCompleteRequest(
        device: newcomer.registration,
        keyBundle: bundle,
      ),
    );
    expect(completed.statusCode, HttpStatus.ok);
  }

  Future<PairingStatusResponse> fetch(String mailboxId, String token) async {
    final http.Response response = await harness.send(
      SyncRoutes.pairingStatus,
      parameters: mailbox(mailboxId),
      credential: AuthCredential(AuthScheme.mailbox, token),
    );
    expect(response.statusCode, HttpStatus.ok);
    return PairingStatusResponse.fromJson(decodeJsonObject(response.body));
  }

  int mailboxes() => harness.database.count('SELECT count(*) FROM mailboxes');

  test('a completed mailbox hands its key bundle over once', () async {
    final String mailboxId = newSyncId();
    final String token = newToken();
    final Uint8List bundle = harness.randomOpaque(120);
    await openMailbox(mailboxId, token);
    await pair(mailboxId, token, bundle);

    final PairingStatusResponse first = await fetch(mailboxId, token);
    final PairingStatusResponse second = await fetch(mailboxId, token);

    expect(first.status, PairingStatus.complete);
    expect(first.accountId, account.accountId);
    expect(first.keyBundle, bundle);
    expect(
      harness.database.selectOne(
        'SELECT complete_payload FROM mailboxes WHERE id = ?',
        <Object?>[mailboxId],
      )!['complete_payload'],
      isNull,
    );
    expect(second.status, PairingStatus.complete);
    expect(second.keyBundle, isNull);
  });

  test('the purge deletes mailboxes past their ten-minute window', () async {
    final String staleId = newSyncId();
    final String staleToken = newToken();
    await openMailbox(staleId, staleToken);
    await pair(staleId, staleToken, harness.randomOpaque(120));
    harness.advance(const Duration(minutes: 5));
    final String freshId = newSyncId();
    await openMailbox(freshId, newToken());
    harness.advance(const Duration(minutes: 5));
    expect(mailboxes(), 2);

    await harness.app.purge();

    expect(
      harness.database.count(
        'SELECT count(*) FROM mailboxes WHERE id = ?',
        <Object?>[staleId],
      ),
      0,
    );
    expect(
      harness.database.count(
        'SELECT count(*) FROM mailboxes WHERE id = ?',
        <Object?>[freshId],
      ),
      1,
    );
  });
}
