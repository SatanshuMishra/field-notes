import 'dart:math';
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:field_notes/data/crypto/device_keys.dart';
import 'package:field_notes/data/crypto/device_names.dart';
import 'package:field_notes/data/crypto/journal_keys.dart';
import 'package:field_notes/data/crypto/key_store.dart';
import 'package:field_notes/data/crypto/recovery_phrase.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/sync/device_name.dart';
import 'package:field_notes/data/sync/relay_client.dart';
import 'package:sync_protocol/sync_protocol.dart';

abstract final class SyncStateKeys {
  static const String relayUrl = 'relay_url';
  static const String syncEnabled = 'sync_enabled';
}

const String syncEnabledValue = 'true';

const String tooManyTriesMessage =
    'Too many tries. Wait a minute and try again.';
const String inviteUsedMessage = 'This invite has already been used.';
const String inviteExpiredMessage = 'This invite has expired.';
const String inviteInvalidMessage =
    "That invite code didn't work. Check it and try again.";
const String updateAppMessage = 'Please update Field Notes to keep syncing.';
const String unreachableMessage =
    "Can't reach that server. Check the address and try again.";
const String notARelayMessage =
    "That address doesn't answer like a Field Notes server.";
const String suspendedMessage = 'Sync is suspended for this journal.';
const String erasedMessage = 'This journal was deleted from the server.';
const String setupFailedMessage = "That didn't work. Try again.";
const String wrongRecoveryWordMessage =
    "That word doesn't match. Check your phrase.";

const int recoveryCheckWords = 2;

typedef RelayClientFactory = RelayClient Function(
  Uri baseUrl,
  DeviceKeys? device,
);

RelayClient defaultRelayClient(Uri baseUrl, DeviceKeys? device) =>
    RelayClient(baseUrl: baseUrl, device: device);

class SyncSetupException implements Exception {
  const SyncSetupException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'SyncSetupException: $message'
      : 'SyncSetupException: $message ($cause)';
}

class WrongRecoveryWord implements Exception {
  const WrongRecoveryWord(this.positions);

  final List<int> positions;

  String get message => wrongRecoveryWordMessage;

  @override
  String toString() => 'WrongRecoveryWord: $positions';
}

String setupMessageFor(
  RelayException error, {
  Map<SyncErrorCode, String> messages = const <SyncErrorCode, String>{},
}) => switch (error) {
  RelayRateLimited() => tooManyTriesMessage,
  RelayUnreachable() => unreachableMessage,
  RelayBadResponse() => notARelayMessage,
  RelayRejected(:final SyncErrorCode code) =>
    messages[code] ??
        switch (code) {
          SyncErrorCode.unsupportedProtocol => updateAppMessage,
          SyncErrorCode.suspended => suspendedMessage,
          SyncErrorCode.journalErased => erasedMessage,
          SyncErrorCode.tooManyRequests => tooManyTriesMessage,
          _ => setupFailedMessage,
        },
};

SyncSetupException setupFailure(
  RelayException error, {
  Map<SyncErrorCode, String> messages = const <SyncErrorCode, String>{},
}) => SyncSetupException(setupMessageFor(error, messages: messages), error);

Future<String?> readSyncState(AppDatabase database, String key) async {
  final SyncState? row = await (database.select(
    database.syncStates,
  )..where((t) => t.key.equals(key))).getSingleOrNull();
  return row?.value;
}

Future<void> writeSyncState(AppDatabase database, String key, String value) =>
    database
        .into(database.syncStates)
        .insertOnConflictUpdate(
          SyncStatesCompanion.insert(key: key, value: value),
        );

Future<void> storeEnrolledDevice({
  required AppDatabase database,
  required KeyStore keyStore,
  required Uri relayUrl,
  required String accountId,
  required JournalKeys journalKeys,
  required DeviceKeys deviceKeys,
  RecoveryPublicKeys? recoveryKeys,
}) async {
  await keyStore.writeJournalKeys(journalKeys);
  await keyStore.writeDeviceKeys(deviceKeys);
  if (recoveryKeys != null) {
    await keyStore.writeRecoveryPublicKeys(recoveryKeys);
  }
  await keyStore.writeAccountId(accountId);
  await writeSyncState(database, SyncStateKeys.relayUrl, '$relayUrl');
}

Future<void> switchSyncOn(AppDatabase database) =>
    writeSyncState(database, SyncStateKeys.syncEnabled, syncEnabledValue);

final class PendingEnrolment {
  PendingEnrolment._({
    required List<String> words,
    required List<int> positions,
    required this._enable,
  }) : words = List<String>.unmodifiable(words),
       positions = List<int>.unmodifiable(positions);

  final List<String> words;
  final List<int> positions;
  final Future<void> Function() _enable;

  Future<void> confirm(List<String> typed) async {
    if (typed.length != positions.length) {
      throw ArgumentError.value(typed.length, 'typed', 'One word per position');
    }
    final List<int> wrong = <int>[
      for (int index = 0; index < positions.length; index++)
        if (normalizeWords(typed[index]).join(' ') !=
            words[positions[index] - 1])
          positions[index],
    ];
    if (wrong.isNotEmpty) {
      throw WrongRecoveryWord(wrong);
    }
    await _enable();
  }
}

final class EnrolmentService {
  EnrolmentService({
    required this._database,
    required this._keyStore,
    this._clientFor = defaultRelayClient,
    this._deviceName = defaultDeviceName,
    Random? random,
  }) : _random = random ?? Random.secure();

  static const Map<SyncErrorCode, String> _inviteMessages =
      <SyncErrorCode, String>{
        SyncErrorCode.inviteUsed: inviteUsedMessage,
        SyncErrorCode.inviteExpired: inviteExpiredMessage,
        SyncErrorCode.inviteInvalid: inviteInvalidMessage,
      };

  final AppDatabase _database;
  final KeyStore _keyStore;
  final RelayClientFactory _clientFor;
  final DeviceNameReader _deviceName;
  final Random _random;

  Future<PendingEnrolment> start({
    required Uri relayUrl,
    required String inviteCode,
  }) async {
    if (inviteCode.trim().isEmpty) {
      throw const SyncSetupException(inviteInvalidMessage);
    }
    final DeviceKeys device = DeviceKeys.generate();
    final JournalKeys journal = JournalKeys.generate();
    final Uint8List seed = newRecoverySeed();
    final RecoveryKeys recovery = RecoveryKeys.fromSeed(seed);
    final String name = await _deviceName();
    final InviteRedeemRequest request = InviteRedeemRequest(
      inviteCode: inviteCode.trim(),
      device: device.registration(
        certificate: device.certifyWith(journal),
        encryptedName: sealDeviceName(name, device.deviceId, journal),
      ),
      recoverySignPublicKey: recovery.signKeyPair.publicKey,
      recoveryBoxPublicKey: recovery.boxKeyPair.publicKey,
      recoveryBoxCertificate: certifyRecoveryKey(
        journal,
        recovery.boxKeyPair.publicKey,
      ),
      recoveryEpochOneCopy: sealEpochOneCopy(
        journal.epochKey(firstEpoch),
        recovery.secretKey,
      ),
    );
    final RelayClient client = _clientFor(relayUrl, device);
    final InviteRedeemResponse redeemed;
    try {
      redeemed = await client.redeemInvite(request);
    } on RelayException catch (error) {
      throw setupFailure(error, messages: _inviteMessages);
    } finally {
      client.close();
    }
    await storeEnrolledDevice(
      database: _database,
      keyStore: _keyStore,
      relayUrl: relayUrl,
      accountId: redeemed.accountId,
      journalKeys: journal,
      deviceKeys: device,
      recoveryKeys: recovery.publicKeys,
    );
    return PendingEnrolment._(
      words: recoveryWords(seed),
      positions: _checkPositions(),
      enable: () => switchSyncOn(_database),
    );
  }

  List<int> _checkPositions() {
    final List<int> all = List<int>.generate(
      recoveryWordCount,
      (int index) => index + 1,
    )..shuffle(_random);
    return all.take(recoveryCheckWords).toList()..sort();
  }
}
