import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:relay_server/src/accounts.dart';
import 'package:sqlite3/sqlite3.dart';
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

  int accounts() => harness.database.count('SELECT count(*) FROM accounts');

  int devices() => harness.database.count('SELECT count(*) FROM devices');

  Future<http.Response> redeem(String code) {
    final TestKeys certifying = harness.signKeys();
    return harness.send(
      SyncRoutes.redeemInvite,
      body: harness.redeemRequest(
        code,
        certifyingKeys: certifying,
        device: harness.newDevice(certifying),
        recoverySignKeys: harness.signKeys(),
        recoveryBoxPublicKey: harness.sodium.crypto.box.keyPair().publicKey,
        recoveryEpochOneCopy: harness.randomOpaque(72),
      ),
    );
  }

  test('an invite creates one account and cannot be reused', () async {
    final CreatedInvite invite = harness.createInvite('Alex');

    final http.Response first = await redeem(invite.code);

    expect(first.statusCode, HttpStatus.ok);
    final String accountId = InviteRedeemResponse.fromJson(
      decodeJsonObject(first.body),
    ).accountId;
    expect(isSyncId(accountId), isTrue);
    expect(accounts(), 1);
    expect(devices(), 1);
    final Row account = harness.database.selectOne(
      'SELECT note, status, current_epoch FROM accounts WHERE id = ?',
      <Object?>[accountId],
    )!;
    expect(account['note'], 'Alex');
    expect(account['status'], 'active');
    expect(account['current_epoch'], 1);
    expect(
      harness.database.count(
        'SELECT count(*) FROM devices WHERE account_id = ? AND status = ?',
        <Object?>[accountId, 'active'],
      ),
      1,
    );
    final InviteSummary used = harness.app.accounts.listInvites().single;
    expect(used.accountId, accountId);
    expect(used.stateAt(harness.now), InviteState.used);

    final http.Response again = await redeem(invite.code);

    expect(again.statusCode, SyncErrorCode.inviteUsed.httpStatus);
    expect(errorOf(again).code, SyncErrorCode.inviteUsed);
    expect(accounts(), 1);
    expect(devices(), 1);
  });

  test('expired and revoked invites are refused', () async {
    final CreatedInvite onTime = harness.createInvite('On time');
    final CreatedInvite late = harness.createInvite('Late');
    harness.advance(inviteLifetime - const Duration(seconds: 1));
    expect((await redeem(onTime.code)).statusCode, HttpStatus.ok);
    expect(accounts(), 1);
    harness.advance(const Duration(seconds: 1));

    final http.Response expired = await redeem(late.code);

    expect(expired.statusCode, SyncErrorCode.inviteExpired.httpStatus);
    expect(errorOf(expired).code, SyncErrorCode.inviteExpired);
    expect(accounts(), 1);
    expect(devices(), 1);

    final CreatedInvite withdrawn = harness.createInvite('Withdrawn');
    expect(harness.app.accounts.revokeInvite(withdrawn.id), isTrue);

    final http.Response revoked = await redeem(withdrawn.code);

    expect(revoked.statusCode, SyncErrorCode.inviteInvalid.httpStatus);
    expect(errorOf(revoked).code, SyncErrorCode.inviteInvalid);

    final http.Response unknown = await redeem('NOT-A-CODE');

    expect(unknown.statusCode, SyncErrorCode.inviteInvalid.httpStatus);
    expect(errorOf(unknown).code, SyncErrorCode.inviteInvalid);
    expect(accounts(), 1);
    expect(devices(), 1);
    expect(
      harness.app.accounts
          .listInvites()
          .map((InviteSummary invite) => invite.stateAt(harness.now))
          .toList(),
      <InviteState>[InviteState.used, InviteState.expired, InviteState.revoked],
    );
  });
}
