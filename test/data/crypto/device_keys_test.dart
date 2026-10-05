import 'dart:typed_data';

import 'package:field_notes/data/crypto/device_keys.dart';
import 'package:field_notes/data/crypto/device_names.dart';
import 'package:field_notes/data/crypto/journal_keys.dart';
import 'package:field_notes/data/crypto/key_store.dart';
import 'package:field_notes/data/crypto/recovery_phrase.dart';
import 'package:field_notes/data/crypto/sodium_loader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sync_protocol/sync_protocol.dart';

final DateTime _seen = DateTime.utc(2026, 10, 5, 9);

DeviceInfo _info(DeviceKeys device, Uint8List certificate) => DeviceInfo(
  deviceId: device.deviceId,
  signPublicKey: device.signKeyPair.publicKey,
  boxPublicKey: device.boxKeyPair.publicKey,
  certificate: certificate,
  encryptedName: Uint8List.fromList(<int>[1, 2, 3]),
  createdAt: _seen,
  lastSeenAt: _seen,
);

DeviceInfo _certified(DeviceKeys device, JournalKeys keys) =>
    _info(device, device.certifyWith(keys));

void main() {
  test('uncertified signers, devices and recovery keys are refused', () {
    final JournalKeys journal = JournalKeys.generate();
    final JournalKeys forger = JournalKeys.generate();
    final Uint8List certifying = journal.certifyingPublicKey;
    final DeviceKeys mac = DeviceKeys.generate();
    final DeviceKeys phone = DeviceKeys.generate();
    final DeviceKeys intruder = DeviceKeys.generate();
    final RecoveryKeys recovery = RecoveryKeys.fromSeed(newRecoverySeed());
    final DeviceInfo macInfo = _certified(mac, journal);
    final DeviceInfo phoneInfo = _certified(phone, journal);

    expect(isCertifiedDevice(certifying, macInfo), isTrue);
    expect(
      isCertifiedDevice(certifying, _certified(intruder, forger)),
      isFalse,
    );
    final Uint8List flipped = Uint8List.fromList(macInfo.certificate)
      ..[10] ^= 0x01;
    expect(isCertifiedDevice(certifying, _info(mac, flipped)), isFalse);
    expect(
      isCertifiedDevice(certifying, _info(intruder, macInfo.certificate)),
      isFalse,
    );
    expect(
      certifiedDevices(certifying, <DeviceInfo>[
        macInfo,
        _certified(intruder, forger),
        phoneInfo,
      ]).map((DeviceInfo device) => device.deviceId),
      <String>[mac.deviceId, phone.deviceId],
    );

    final Uint8List recoveryCertificate = certifyRecoveryKey(
      journal,
      recovery.boxKeyPair.publicKey,
    );
    expect(
      verifyRecoveryCertificate(
        certifying,
        recoveryBoxPublicKey: recovery.boxKeyPair.publicKey,
        certificate: recoveryCertificate,
      ),
      isTrue,
    );
    expect(
      verifyRecoveryCertificate(
        certifying,
        recoveryBoxPublicKey: recovery.boxKeyPair.publicKey,
        certificate: certifyRecoveryKey(forger, recovery.boxKeyPair.publicKey),
      ),
      isFalse,
    );
    expect(
      verifyRecoveryCertificate(
        certifying,
        recoveryBoxPublicKey: intruder.boxKeyPair.publicKey,
        certificate: recoveryCertificate,
      ),
      isFalse,
    );

    final Uint8List epochTwo = JournalKeys.newEpochKey();
    final List<RotationRecipient> recipients = <RotationRecipient>[
      RotationRecipient.device(phoneInfo),
      RotationRecipient.recovery(recovery.boxKeyPair.publicKey),
    ];
    final EpochRotation honest = makeRotation(
      epoch: 2,
      epochKey: epochTwo,
      signer: mac,
      recipients: recipients,
    );
    final List<DeviceInfo> listed = <DeviceInfo>[macInfo, phoneInfo];
    expect(
      verifiedEpochKeys(
        rotations: <EpochRotation>[honest],
        devices: listed,
        recipient: phone.recipient,
        boxKeyPair: phone.boxKeyPair,
        certifyingPublicKey: certifying,
      ),
      <int, Uint8List>{2: epochTwo},
    );
    expect(
      verifiedEpochKeys(
        rotations: <EpochRotation>[honest],
        devices: listed,
        recipient: EpochKeyDelivery.recoveryRecipient,
        boxKeyPair: recovery.boxKeyPair,
        certifyingPublicKey: certifying,
      ),
      <int, Uint8List>{2: epochTwo},
    );

    final EpochRotation forged = makeRotation(
      epoch: 2,
      epochKey: JournalKeys.newEpochKey(),
      signer: intruder,
      recipients: recipients,
    );
    final List<DeviceInfo> withIntruder = <DeviceInfo>[
      ...listed,
      _certified(intruder, forger),
    ];
    for (final EpochKeyDelivery delivery in forged.deliveries) {
      expect(
        verifyDelivery(
          epoch: 2,
          signerDeviceId: intruder.deviceId,
          delivery: delivery,
          devices: withIntruder,
          certifyingPublicKey: certifying,
        ),
        isFalse,
      );
    }
    expect(
      verifiedEpochKeys(
        rotations: <EpochRotation>[forged],
        devices: withIntruder,
        recipient: phone.recipient,
        boxKeyPair: phone.boxKeyPair,
        certifyingPublicKey: certifying,
      ),
      isEmpty,
    );
    expect(
      verifiedEpochKeys(
        rotations: <EpochRotation>[honest],
        devices: <DeviceInfo>[phoneInfo],
        recipient: phone.recipient,
        boxKeyPair: phone.boxKeyPair,
        certifyingPublicKey: certifying,
      ),
      isEmpty,
    );
    final EpochKeyDelivery honestDelivery = honest.deliveries.first;
    final EpochRotation swapped = EpochRotation(
      epoch: 2,
      signerDeviceId: mac.deviceId,
      deliveries: <EpochKeyDelivery>[
        EpochKeyDelivery(
          recipient: honestDelivery.recipient,
          sealed: forged.deliveries.first.sealed,
          signature: honestDelivery.signature,
        ),
      ],
    );
    expect(
      verifiedEpochKeys(
        rotations: <EpochRotation>[swapped],
        devices: listed,
        recipient: phone.recipient,
        boxKeyPair: phone.boxKeyPair,
        certifyingPublicKey: certifying,
      ),
      isEmpty,
    );
    final EpochRotation renumbered = EpochRotation(
      epoch: 3,
      signerDeviceId: honest.signerDeviceId,
      deliveries: honest.deliveries,
    );
    expect(
      verifiedEpochKeys(
        rotations: <EpochRotation>[renumbered],
        devices: listed,
        recipient: phone.recipient,
        boxKeyPair: phone.boxKeyPair,
        certifyingPublicKey: certifying,
      ),
      isEmpty,
    );

    final JournalKeys rotated = journal.withEpoch(2, epochTwo);
    final Uint8List pairingKey = randomBytes(32);
    final Uint8List bundle = sealPairingBundle(rotated, pairingKey);
    final JournalKeys received = openPairingBundle(bundle, pairingKey);
    expect(received.epochKeys, rotated.epochKeys);
    expect(received.currentEpoch, 2);
    expect(
      () => openPairingBundle(bundle, randomBytes(32)),
      throwsA(isA<CryptoException>()),
    );
    expect(
      () => openPairingBundle(
        Uint8List.fromList(bundle)..[bundle.length - 1] ^= 0x01,
        pairingKey,
      ),
      throwsA(isA<CryptoException>()),
    );
  });

  test('the epoch-one copy opens only with the recovery secret key', () {
    final JournalKeys journal = JournalKeys.generate();
    final RecoveryKeys recovery = RecoveryKeys.fromSeed(newRecoverySeed());
    final RecoveryKeys stranger = RecoveryKeys.fromSeed(newRecoverySeed());

    final Uint8List copy = sealEpochOneCopy(
      journal.epochKey(1),
      recovery.secretKey,
    );

    expect(openEpochOneCopy(copy, recovery.secretKey), journal.epochKey(1));
    expect(
      () => openEpochOneCopy(copy, stranger.secretKey),
      throwsA(isA<CryptoException>()),
    );
    expect(
      JournalKeys(
        epochKeys: <int, List<int>>{
          1: openEpochOneCopy(copy, recovery.secretKey),
        },
        currentEpoch: 1,
      ).certifyingPublicKey,
      journal.certifyingPublicKey,
    );
  });

  test('device names stay readable after a rotation and bind the device', () {
    final JournalKeys journal = JournalKeys.generate();
    final String deviceId = newSyncId();
    final Uint8List sealed = sealDeviceName('Pixel 9 Pro', deviceId, journal);
    final JournalKeys rotated = journal.withEpoch(2, JournalKeys.newEpochKey());

    expect(openDeviceName(sealed, deviceId, journal), 'Pixel 9 Pro');
    expect(openDeviceName(sealed, deviceId, rotated), 'Pixel 9 Pro');
    expect(sealed.length, sealDeviceName('Mac', deviceId, journal).length);
    expect(
      () => openDeviceName(sealed, newSyncId(), journal),
      throwsA(isA<CryptoException>()),
    );
    expect(
      () => openDeviceName(sealed, deviceId, JournalKeys.generate()),
      throwsA(isA<CryptoException>()),
    );
  });

  test('the key store keeps every key until it is wiped', () async {
    final MemorySecureValues values = MemorySecureValues();
    final KeyStore store = KeyStore(values);
    final JournalKeys journal = JournalKeys.generate().withEpoch(
      2,
      JournalKeys.newEpochKey(),
    );
    final DeviceKeys device = DeviceKeys.generate();
    final RecoveryKeys recovery = RecoveryKeys.fromSeed(newRecoverySeed());
    final DateTime expiry = DateTime.utc(2026, 10, 12, 9);

    await store.writeJournalKeys(journal);
    await store.writeDeviceKeys(device);
    await store.writeRecoveryPublicKeys(recovery.publicKeys);
    await store.writeAccountId('account-1');
    await store.writeUploadPass(UploadPass(token: 'pass', expiresAt: expiry));

    final KeyStore reopened = KeyStore(values);
    final JournalKeys? readJournal = await reopened.readJournalKeys();
    final DeviceKeys? readDevice = await reopened.readDeviceKeys();
    final RecoveryPublicKeys? readRecovery = await reopened
        .readRecoveryPublicKeys();
    final UploadPass? readPass = await reopened.readUploadPass();
    expect(readJournal?.epochKeys, journal.epochKeys);
    expect(readJournal?.currentEpoch, 2);
    expect(readDevice?.deviceId, device.deviceId);
    expect(readDevice?.signKeyPair.secretKey, device.signKeyPair.secretKey);
    expect(readDevice?.boxKeyPair.secretKey, device.boxKeyPair.secretKey);
    expect(await reopened.readDeviceId(), device.deviceId);
    expect(readRecovery?.boxPublicKey, recovery.boxKeyPair.publicKey);
    expect(readRecovery?.signPublicKey, recovery.signKeyPair.publicKey);
    expect(await reopened.readAccountId(), 'account-1');
    expect(readPass?.token, 'pass');
    expect(readPass?.expiresAt, expiry);

    await reopened.wipe();

    expect(values.snapshot, isEmpty);
    expect(await reopened.readJournalKeys(), isNull);
    expect(await reopened.readDeviceKeys(), isNull);
    expect(await reopened.readUploadPass(), isNull);
  });
}
