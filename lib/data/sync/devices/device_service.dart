import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:field_notes/data/crypto/device_keys.dart';
import 'package:field_notes/data/crypto/device_names.dart';
import 'package:field_notes/data/crypto/journal_keys.dart';
import 'package:field_notes/data/crypto/key_store.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/sync/enrolment/enrolment_service.dart';
import 'package:field_notes/data/sync/relay_client.dart';
import 'package:sync_protocol/sync_protocol.dart';

const String rotationStatePrefix = 'rotation_';
const String unnamedDeviceName = 'Unnamed device';

String rotationStateKey(int epoch) => '$rotationStatePrefix$epoch';

class LastDeviceException implements Exception {
  const LastDeviceException();

  @override
  String toString() => 'LastDeviceException: the last device cannot be removed';
}

final class JournalDevice {
  JournalDevice({
    required this.deviceId,
    required this.name,
    required DateTime createdAt,
    required DateTime lastSeenAt,
    required this.isThisDevice,
  }) : createdAt = createdAt.toUtc(),
       lastSeenAt = lastSeenAt.toUtc();

  final String deviceId;
  final String name;
  final DateTime createdAt;
  final DateTime lastSeenAt;
  final bool isThisDevice;
}

final class OwnRotation {
  const OwnRotation({required this.removedDeviceId, required this.rotation});

  factory OwnRotation.fromJson(Map<String, Object?> json) {
    final Object? removed = json['removedDeviceId'];
    final Object? rotation = json['rotation'];
    if (removed is! String || rotation is! Map<String, Object?>) {
      throw const FormatException('Invalid kept rotation');
    }
    return OwnRotation(
      removedDeviceId: removed,
      rotation: EpochRotation.fromJson(rotation),
    );
  }

  final String removedDeviceId;
  final EpochRotation rotation;

  int get epoch => rotation.epoch;

  Map<String, Object?> toJson() => <String, Object?>{
    'removedDeviceId': removedDeviceId,
    'rotation': rotation.toJson(),
  };
}

final class DeviceService {
  DeviceService({
    required this._database,
    required this._keyStore,
    required this._client,
  });

  final AppDatabase _database;
  final KeyStore _keyStore;
  final RelayClient _client;

  Future<List<JournalDevice>> list() async {
    final JournalKeys journal = await _journalKeys();
    final String? thisDevice = await _keyStore.readDeviceId();
    final DeviceListResponse response = await _client.devices();
    return List<JournalDevice>.unmodifiable(<JournalDevice>[
      for (final DeviceInfo device in certifiedDevices(
        journal.certifyingPublicKey,
        response.devices,
      ))
        JournalDevice(
          deviceId: device.deviceId,
          name: _nameOf(device, journal),
          createdAt: device.createdAt,
          lastSeenAt: device.lastSeenAt,
          isThisDevice: device.deviceId == thisDevice,
        ),
    ]);
  }

  Future<int> remove(String deviceId) async {
    final DeviceKeys self = await _deviceKeys();
    final EpochKeysResponse keys = await _client.keys();
    final JournalKeys journal = await _adopt(keys, self);
    final List<DeviceInfo> active = certifiedDevices(
      journal.certifyingPublicKey,
      (await _client.devices()).devices,
    );
    if (!active.any((DeviceInfo device) => device.deviceId == deviceId)) {
      throw ArgumentError.value(deviceId, 'deviceId', 'Not a journal device');
    }
    final List<DeviceInfo> remaining = <DeviceInfo>[
      for (final DeviceInfo device in active)
        if (device.deviceId != deviceId) device,
    ];
    if (remaining.isEmpty) {
      throw const LastDeviceException();
    }
    final bool recoveryCertified = verifyRecoveryCertificate(
      journal.certifyingPublicKey,
      recoveryBoxPublicKey: keys.recoveryBoxPublicKey,
      certificate: keys.recoveryBoxCertificate,
    );
    final int epoch = keys.currentEpoch + 1;
    final Uint8List epochKey = JournalKeys.newEpochKey();
    final EpochRotation rotation = makeRotation(
      epoch: epoch,
      epochKey: epochKey,
      signer: self,
      recipients: <RotationRecipient>[
        for (final DeviceInfo device in remaining)
          RotationRecipient.device(device),
        if (recoveryCertified)
          RotationRecipient.recovery(keys.recoveryBoxPublicKey),
      ],
    );
    await _client.removeDevice(
      deviceId,
      DeviceRemoveRequest(rotation: rotation),
    );
    await writeSyncState(
      _database,
      rotationStateKey(epoch),
      jsonEncode(
        OwnRotation(removedDeviceId: deviceId, rotation: rotation).toJson(),
      ),
    );
    if (deviceId != self.deviceId) {
      await _keyStore.writeJournalKeys(journal.withEpoch(epoch, epochKey));
    }
    return epoch;
  }

  Future<List<OwnRotation>> ownRotationsAbove(int epoch) async {
    final List<SyncState> rows = await (_database.select(
      _database.syncStates,
    )..where((t) => t.key.like('$rotationStatePrefix%'))).get();
    final List<OwnRotation> rotations = <OwnRotation>[
      for (final SyncState row in rows)
        OwnRotation.fromJson(decodeJsonObject(row.value)),
    ];
    return List<OwnRotation>.unmodifiable(
      rotations.where((OwnRotation kept) => kept.epoch > epoch).toList()
        ..sort((OwnRotation a, OwnRotation b) => a.epoch.compareTo(b.epoch)),
    );
  }

  Future<JournalKeys> refreshKeys() async {
    final DeviceKeys self = await _deviceKeys();
    return _adopt(await _client.keys(), self);
  }

  Future<JournalKeys> _adopt(EpochKeysResponse keys, DeviceKeys self) async {
    final JournalKeys journal = await _journalKeys();
    final Map<int, Uint8List> verified = verifiedEpochKeys(
      rotations: keys.rotations,
      devices: keys.devices,
      recipient: self.recipient,
      boxKeyPair: self.boxKeyPair,
      certifyingPublicKey: journal.certifyingPublicKey,
    );
    final JournalKeys adopted = verified.entries
        .where((MapEntry<int, Uint8List> entry) => !journal.hasEpoch(entry.key))
        .fold(
          journal,
          (JournalKeys held, MapEntry<int, Uint8List> entry) =>
              held.withEpoch(entry.key, entry.value),
        );
    if (adopted.epochs.length != journal.epochs.length) {
      await _keyStore.writeJournalKeys(adopted);
    }
    return adopted;
  }

  Future<JournalKeys> _journalKeys() async {
    final JournalKeys? journal = await _keyStore.readJournalKeys();
    if (journal == null) {
      throw StateError('This device holds no journal keys');
    }
    return journal;
  }

  Future<DeviceKeys> _deviceKeys() async {
    final DeviceKeys? device = await _keyStore.readDeviceKeys();
    if (device == null) {
      throw StateError('This device holds no device keys');
    }
    return device;
  }

  static String _nameOf(DeviceInfo device, JournalKeys journal) {
    try {
      return openDeviceName(device.encryptedName, device.deviceId, journal);
    } on CryptoException {
      return unnamedDeviceName;
    }
  }
}
