import 'dart:typed_data';

import 'package:field_notes/data/crypto/device_keys.dart';
import 'package:field_notes/data/crypto/device_names.dart';
import 'package:field_notes/data/crypto/journal_keys.dart';
import 'package:field_notes/data/crypto/key_store.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/sync/device_name.dart';
import 'package:field_notes/data/sync/devices/device_service.dart';
import 'package:field_notes/data/sync/enrolment/enrolment_service.dart';
import 'package:field_notes/data/sync/pairing/pairing_code.dart';
import 'package:field_notes/data/sync/relay_client.dart';
import 'package:sync_protocol/sync_protocol.dart';

const String pairingRetryMessage =
    "That code didn't work. Make a new one on your other device.";
const String plainHttpPairingMessage =
    "Your other device's server address starts with http://. On that device, "
    'change it to an https:// address under Sync & storage, then make a new '
    'code.';
const String pairingRefusedMessage =
    "That device didn't have the right code. Make a new code and try again.";
const String pairingExpiredMessage = 'This code has expired. Make a new one.';
const String relayAddressNeededMessage =
    'Type your server address with the 8 words.';
const String pairingCancelledMessage = 'Joining was cancelled.';
const String pairingTakenMessage =
    'Another device already used this code. On your other device, choose '
    '"Don\'t add", then make a new code.';
const String pairingDeclinedMessage = 'Nothing was joined.';
const Duration pairingPollInterval = Duration(seconds: 2);
const int shownDeviceNameLength = 40;

final RegExp _spacing = RegExp(r'\s+', unicode: true);
final RegExp _hiddenCharacters = RegExp(
  r'[\p{Cc}\p{Cf}\p{Co}\p{Cs}\p{Zl}\p{Zp}]',
  unicode: true,
);

String shownDeviceName(String name) {
  final String plain = name
      .replaceAll(_spacing, ' ')
      .replaceAll(_hiddenCharacters, '')
      .trim();
  if (plain.isEmpty) {
    return unnamedDeviceName;
  }
  final List<int> runes = plain.runes.toList();
  if (runes.length <= shownDeviceNameLength) {
    return plain;
  }
  return '${String.fromCharCodes(runes.take(shownDeviceNameLength - 1)).trimRight()}\u2026';
}

typedef PairingWait = Future<void> Function(Duration duration);

typedef JournalConfirmation = Future<bool> Function(String? journalLabel);

Future<void> waitFor(Duration duration) => Future<void>.delayed(duration);

DateTime _utcNow() => DateTime.now().toUtc();

class PairingRefused extends SyncSetupException {
  const PairingRefused() : super(pairingRefusedMessage);
}

class PairingCancelled extends SyncSetupException {
  const PairingCancelled() : super(pairingCancelledMessage);
}

class PairingTaken extends SyncSetupException {
  const PairingTaken() : super(pairingTakenMessage);
}

class PairingDeclined extends SyncSetupException {
  const PairingDeclined() : super(pairingDeclinedMessage);
}

bool _neverCancelled() => false;

void _ignoreComparison(String comparison) {}

final class PairingCandidate {
  const PairingCandidate({
    required this.deviceName,
    required this.join,
    required this.comparison,
  });

  final String deviceName;
  final PairingJoinRequest join;
  final String comparison;

  String get deviceId => join.device.deviceId;
}

final class HostedPairing {
  HostedPairing._({
    required this.code,
    required this.expiresAt,
    required this._client,
    required this._journal,
    required this._pollInterval,
    required this._wait,
  });

  static const Map<SyncErrorCode, String> _messages = <SyncErrorCode, String>{
    SyncErrorCode.pairingExpired: pairingExpiredMessage,
    SyncErrorCode.notFound: pairingExpiredMessage,
  };

  final PairingCode code;
  final DateTime expiresAt;
  final RelayClient _client;
  final JournalKeys _journal;
  final Duration _pollInterval;
  final PairingWait _wait;

  Future<PairingCandidate> waitForJoin() async {
    while (true) {
      final PairingStatusResponse status;
      try {
        status = await _client.pairingStatus(code.mailboxId);
      } on RelayException catch (error) {
        throw setupFailure(error, messages: _messages);
      }
      final PairingJoinRequest? join = status.join;
      if (status.status != PairingStatus.open && join != null) {
        return _verify(join);
      }
      await _wait(_pollInterval);
    }
  }

  Future<void> confirm(PairingCandidate candidate) async {
    final DeviceRegistration joined = _verify(candidate.join).join.device;
    final DeviceRegistration certified = DeviceRegistration(
      deviceId: joined.deviceId,
      signPublicKey: joined.signPublicKey,
      boxPublicKey: joined.boxPublicKey,
      certificate: certifyDevice(
        _journal,
        deviceId: joined.deviceId,
        signPublicKey: joined.signPublicKey,
        boxPublicKey: joined.boxPublicKey,
      ),
      encryptedName: sealDeviceName(
        candidate.deviceName,
        joined.deviceId,
        _journal,
      ),
    );
    try {
      await _client.completePairing(
        code.mailboxId,
        PairingCompleteRequest(
          device: certified,
          keyBundle: sealPairingBundleFor(
            _journal,
            code.pairingKey,
            joined.boxPublicKey,
          ),
        ),
      );
    } on RelayException catch (error) {
      throw setupFailure(error, messages: _messages);
    }
  }

  void close() => _client.close();

  PairingCandidate _verify(PairingJoinRequest join) {
    final DeviceRegistration device = join.device;
    if (!code.authenticates(join) || !_possesses(device)) {
      throw const PairingRefused();
    }
    try {
      return PairingCandidate(
        deviceName: shownDeviceName(
          openNameUnder(device.encryptedName, device.deviceId, code.pairingKey),
        ),
        join: join,
        comparison: code.comparisonFor(device),
      );
    } on CryptoException {
      throw const PairingRefused();
    }
  }

  static bool _possesses(DeviceRegistration device) {
    try {
      return verifySignature(
        message: deviceCertificateBytes(
          deviceId: device.deviceId,
          signPublicKey: device.signPublicKey,
          boxPublicKey: device.boxPublicKey,
        ),
        signature: device.certificate,
        publicKey: device.signPublicKey,
      );
    } on FormatException {
      return false;
    }
  }
}

final class PairingService {
  PairingService({
    required this._database,
    required this._keyStore,
    this._clientFor = defaultRelayClient,
    this._deviceName = defaultDeviceName,
    this._pollInterval = pairingPollInterval,
    this._wait = waitFor,
    this._clock = _utcNow,
  });

  static const Map<SyncErrorCode, String> _joinMessages =
      <SyncErrorCode, String>{
        SyncErrorCode.unauthorized: pairingRetryMessage,
        SyncErrorCode.pairingExpired: pairingRetryMessage,
        SyncErrorCode.notFound: pairingRetryMessage,
        SyncErrorCode.badRequest: pairingRetryMessage,
      };

  final AppDatabase _database;
  final KeyStore _keyStore;
  final RelayClientFactory _clientFor;
  final DeviceNameReader _deviceName;
  final Duration _pollInterval;
  final PairingWait _wait;
  final DateTime Function() _clock;

  Future<HostedPairing> open() async {
    final String? address = await readSyncState(
      _database,
      SyncStateKeys.relayUrl,
    );
    final DeviceKeys? device = await _keyStore.readDeviceKeys();
    final JournalKeys? journal = await _keyStore.readJournalKeys();
    if (address == null || device == null || journal == null) {
      throw StateError('Sync is not set up on this device');
    }
    final Uri relayUrl = Uri.parse(address);
    final PairingCode code = PairingCode.generate(relayUrl: relayUrl);
    final RelayClient client = _clientFor(relayUrl, device);
    try {
      await client.openPairing(
        PairingOpenRequest(
          mailboxId: code.mailboxId,
          tokenHash: mailboxTokenHash(code.mailboxToken),
        ),
      );
    } on RelayException catch (error) {
      client.close();
      throw setupFailure(error);
    }
    return HostedPairing._(
      code: code,
      expiresAt: _clock().add(pairingLifetime),
      client: client,
      journal: journal,
      pollInterval: _pollInterval,
      wait: _wait,
    );
  }

  Future<void> join(
    String code, {
    required JournalConfirmation confirmJournal,
    Uri? relayUrl,
    bool Function() cancelled = _neverCancelled,
    void Function(String comparison) onComparison = _ignoreComparison,
  }) async {
    final PairingCode parsed;
    try {
      parsed = PairingCode.parse(code);
    } on PlainHttpPairingCodeException catch (error) {
      throw SyncSetupException(plainHttpPairingMessage, error);
    } on PairingCodeException catch (error) {
      throw SyncSetupException(pairingRetryMessage, error);
    }
    final Uri? address = parsed.relayUrl ?? relayUrl;
    if (address == null) {
      throw const SyncSetupException(relayAddressNeededMessage);
    }
    final DeviceKeys device = DeviceKeys.generate();
    final DeviceRegistration registration = device.registration(
      certificate: device.sign(
        deviceCertificateBytes(
          deviceId: device.deviceId,
          signPublicKey: device.signKeyPair.publicKey,
          boxPublicKey: device.boxKeyPair.publicKey,
        ),
      ),
      encryptedName: sealNameUnder(
        await _deviceName(),
        device.deviceId,
        parsed.pairingKey,
      ),
    );
    final RelayClient client = _clientFor(address, device);
    try {
      _stopIf(cancelled);
      final PairingStatusResponse waiting = await client.mailboxStatus(
        parsed.mailboxId,
        parsed.mailboxToken,
      );
      if (waiting.status != PairingStatus.open) {
        throw const PairingTaken();
      }
      final bool confirmed = await confirmJournal(waiting.journalLabel);
      _stopIf(cancelled);
      if (!confirmed) {
        throw const PairingDeclined();
      }
      await _post(client, parsed, registration);
      onComparison(parsed.comparisonFor(registration));
      final PairingStatusResponse completed = await _awaitCompletion(
        client,
        parsed,
        cancelled,
      );
      final JournalKeys journal = _openBundle(completed, parsed, device);
      await client.signIn();
      final EpochKeysResponse keys = await client.keys();
      final bool certified = keys.devices.any(
        (DeviceInfo info) =>
            info.deviceId == device.deviceId &&
            isCertifiedDevice(journal.certifyingPublicKey, info),
      );
      if (!certified) {
        throw const SyncSetupException(pairingRetryMessage);
      }
      _stopIf(cancelled);
      await storeEnrolledDevice(
        database: _database,
        keyStore: _keyStore,
        relayUrl: address,
        accountId: completed.accountId!,
        journalKeys: journal,
        deviceKeys: device,
      );
      await switchSyncOn(_database);
    } on RelayException catch (error) {
      throw setupFailure(error, messages: _joinMessages);
    } finally {
      client.close();
    }
  }

  static Future<void> _post(
    RelayClient client,
    PairingCode code,
    DeviceRegistration registration,
  ) async {
    try {
      await client.joinPairing(
        code.mailboxId,
        code.mailboxToken,
        PairingJoinRequest(
          device: registration,
          authenticator: code.authenticatorFor(registration),
        ),
      );
    } on RelayRejected catch (error) {
      if (error.code == SyncErrorCode.badRequest &&
          (await client.mailboxStatus(
                code.mailboxId,
                code.mailboxToken,
              )).status !=
              PairingStatus.open) {
        throw const PairingTaken();
      }
      rethrow;
    }
  }

  static void _stopIf(bool Function() cancelled) {
    if (cancelled()) {
      throw const PairingCancelled();
    }
  }

  Future<PairingStatusResponse> _awaitCompletion(
    RelayClient client,
    PairingCode code,
    bool Function() cancelled,
  ) async {
    final DateTime deadline = _clock().add(pairingLifetime);
    while (_clock().isBefore(deadline)) {
      await _wait(_pollInterval);
      _stopIf(cancelled);
      final PairingStatusResponse status = await client.mailboxStatus(
        code.mailboxId,
        code.mailboxToken,
      );
      if (status.status == PairingStatus.complete) {
        return status;
      }
    }
    throw const SyncSetupException(pairingRetryMessage);
  }

  static JournalKeys _openBundle(
    PairingStatusResponse completed,
    PairingCode code,
    DeviceKeys device,
  ) {
    final Uint8List? bundle = completed.keyBundle;
    if (bundle == null || completed.accountId == null) {
      throw const SyncSetupException(pairingRetryMessage);
    }
    try {
      return openPairingBundleFor(bundle, code.pairingKey, device.boxKeyPair);
    } on CryptoException {
      try {
        return openPairingBundle(bundle, code.pairingKey);
      } on CryptoException catch (error) {
        throw SyncSetupException(pairingRetryMessage, error);
      }
    }
  }
}
