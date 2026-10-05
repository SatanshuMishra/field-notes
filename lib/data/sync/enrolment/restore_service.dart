import 'dart:typed_data';

import 'package:field_notes/data/crypto/device_keys.dart';
import 'package:field_notes/data/crypto/device_names.dart';
import 'package:field_notes/data/crypto/journal_keys.dart';
import 'package:field_notes/data/crypto/key_store.dart';
import 'package:field_notes/data/crypto/recovery_phrase.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/sync/device_name.dart';
import 'package:field_notes/data/sync/enrolment/enrolment_service.dart';
import 'package:field_notes/data/sync/relay_client.dart';
import 'package:sync_protocol/sync_protocol.dart';

const String phraseLengthMessage =
    'A recovery phrase has 12 words. Check your phrase.';
const String phraseChecksumMessage =
    "Those words don't make a recovery phrase. Check them and try again.";
const String noJournalMessage =
    'No journal on that server uses this recovery phrase.';
const String phraseDoesNotOpenMessage =
    "This recovery phrase doesn't open the journal on that server.";

String unknownWordMessage(String word) =>
    '"$word" isn\'t one of the recovery words. Check your phrase.';

String recoveryPhraseMessage(RecoveryPhraseException error) =>
    switch (error.problem) {
      RecoveryPhraseProblem.unknownWord => unknownWordMessage(error.word ?? ''),
      RecoveryPhraseProblem.wrongLength => phraseLengthMessage,
      RecoveryPhraseProblem.badChecksum => phraseChecksumMessage,
    };

final class RestoredJournal {
  const RestoredJournal({
    required this.accountId,
    required this.deviceId,
    required this.epochs,
  });

  final String accountId;
  final String deviceId;
  final List<int> epochs;
}

final class RestoreService {
  RestoreService({
    required this._database,
    required this._keyStore,
    this._clientFor = defaultRelayClient,
    this._deviceName = defaultDeviceName,
  });

  static const Map<SyncErrorCode, String> _restoreMessages =
      <SyncErrorCode, String>{
        SyncErrorCode.notFound: noJournalMessage,
        SyncErrorCode.unauthorized: phraseDoesNotOpenMessage,
      };

  final AppDatabase _database;
  final KeyStore _keyStore;
  final RelayClientFactory _clientFor;
  final DeviceNameReader _deviceName;

  Future<RestoredJournal> restore({
    required Uri relayUrl,
    required String phrase,
  }) async {
    final Uint8List seed;
    try {
      seed = decodeRecoveryPhrase(phrase);
    } on RecoveryPhraseException catch (error) {
      throw SyncSetupException(recoveryPhraseMessage(error), error);
    }
    final RecoveryKeys recovery = RecoveryKeys.fromSeed(seed);
    final DeviceKeys device = DeviceKeys.generate();
    final RelayClient client = _clientFor(relayUrl, device);
    try {
      final RestoreResponse restored = await _prove(client, recovery);
      final JournalKeys journal = _openJournal(restored, recovery);
      await client.registerRestoredDevice(
        RestoreRegisterRequest(
          restoreToken: restored.restoreToken,
          device: device.registration(
            certificate: device.certifyWith(journal),
            encryptedName: sealDeviceName(
              await _deviceName(),
              device.deviceId,
              journal,
            ),
          ),
        ),
      );
      await storeEnrolledDevice(
        database: _database,
        keyStore: _keyStore,
        relayUrl: relayUrl,
        accountId: restored.accountId,
        journalKeys: journal,
        deviceKeys: device,
        recoveryKeys: recovery.publicKeys,
      );
      await switchSyncOn(_database);
      return RestoredJournal(
        accountId: restored.accountId,
        deviceId: device.deviceId,
        epochs: journal.epochs,
      );
    } on RelayException catch (error) {
      throw setupFailure(error, messages: _restoreMessages);
    } finally {
      client.close();
    }
  }

  Future<RestoreResponse> _prove(
    RelayClient client,
    RecoveryKeys recovery,
  ) async {
    final Uint8List signPublicKey = recovery.signKeyPair.publicKey;
    final ChallengeResponse challenge = await client.restoreChallenge(
      signPublicKey,
    );
    return client.restore(
      RestoreRequest(
        challengeId: challenge.challengeId,
        signature: signDetached(
          restoreChallengeBytes(
            challengeId: challenge.challengeId,
            nonce: challenge.nonce,
            recoverySignPublicKey: signPublicKey,
          ),
          recovery.signKeyPair,
        ),
      ),
    );
  }

  JournalKeys _openJournal(RestoreResponse restored, RecoveryKeys recovery) {
    final JournalKeys first;
    try {
      first = JournalKeys(
        epochKeys: <int, List<int>>{
          firstEpoch: openEpochOneCopy(
            restored.recoveryEpochOneCopy,
            recovery.secretKey,
          ),
        },
        currentEpoch: firstEpoch,
      );
    } on CryptoException catch (error) {
      throw SyncSetupException(phraseDoesNotOpenMessage, error);
    }
    final Map<int, Uint8List> later = verifiedEpochKeys(
      rotations: restored.rotations,
      devices: restored.devices,
      recipient: EpochKeyDelivery.recoveryRecipient,
      boxKeyPair: recovery.boxKeyPair,
      certifyingPublicKey: first.certifyingPublicKey,
    );
    return later.entries.fold(
      first,
      (JournalKeys keys, MapEntry<int, Uint8List> entry) =>
          keys.withEpoch(entry.key, entry.value),
    );
  }
}
