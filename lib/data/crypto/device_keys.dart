import 'dart:convert';
import 'dart:typed_data';

import 'package:field_notes/data/crypto/journal_keys.dart';
import 'package:field_notes/data/crypto/sodium_loader.dart';
import 'package:sodium/sodium.dart';
import 'package:sync_protocol/sync_protocol.dart';

final class DeviceKeys {
  DeviceKeys({
    required this.deviceId,
    required this.signKeyPair,
    required this.boxKeyPair,
  });

  factory DeviceKeys.generate() {
    final Sodium sodium = loadSodium();
    return DeviceKeys(
      deviceId: newSyncId(),
      signKeyPair: RawKeyPair.take(sodium.crypto.sign.keyPair()),
      boxKeyPair: RawKeyPair.take(sodium.crypto.box.keyPair()),
    );
  }

  factory DeviceKeys.fromJson(Map<String, Object?> json) {
    Uint8List bytes(String key) => switch (json[key]) {
      final String encoded => decodeBase64Url(encoded),
      _ => throw FormatException('Invalid $key'),
    };
    final Object? deviceId = json['deviceId'];
    if (deviceId is! String || !isSyncId(deviceId)) {
      throw const FormatException('Invalid deviceId');
    }
    return DeviceKeys(
      deviceId: deviceId,
      signKeyPair: RawKeyPair(
        publicKey: bytes('signPublicKey'),
        secretKey: bytes('signSecretKey'),
      ),
      boxKeyPair: RawKeyPair(
        publicKey: bytes('boxPublicKey'),
        secretKey: bytes('boxSecretKey'),
      ),
    );
  }

  final String deviceId;
  final RawKeyPair signKeyPair;
  final RawKeyPair boxKeyPair;

  String get recipient => EpochKeyDelivery.deviceRecipient(deviceId);

  Uint8List sign(Uint8List message) => signDetached(message, signKeyPair);

  Uint8List certifyWith(JournalKeys keys) => certifyDevice(
    keys,
    deviceId: deviceId,
    signPublicKey: signKeyPair.publicKey,
    boxPublicKey: boxKeyPair.publicKey,
  );

  DeviceRegistration registration({
    required Uint8List certificate,
    required Uint8List encryptedName,
  }) => DeviceRegistration(
    deviceId: deviceId,
    signPublicKey: signKeyPair.publicKey,
    boxPublicKey: boxKeyPair.publicKey,
    certificate: certificate,
    encryptedName: encryptedName,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'deviceId': deviceId,
    'signPublicKey': encodeBase64Url(signKeyPair.publicKey),
    'signSecretKey': encodeBase64Url(signKeyPair.secretKey),
    'boxPublicKey': encodeBase64Url(boxKeyPair.publicKey),
    'boxSecretKey': encodeBase64Url(boxKeyPair.secretKey),
  };
}

Uint8List signDetached(Uint8List message, RawKeyPair signer) => useSecureKey(
  signer.secretKey,
  (SecureKey key) =>
      loadSodium().crypto.sign.detached(message: message, secretKey: key),
);

bool verifySignature({
  required Uint8List message,
  required Uint8List signature,
  required Uint8List publicKey,
}) {
  final Sign sign = loadSodium().crypto.sign;
  if (signature.length != sign.bytes ||
      publicKey.length != sign.publicKeyBytes) {
    return false;
  }
  try {
    return sign.verifyDetached(
      message: message,
      signature: signature,
      publicKey: publicKey,
    );
  } on SodiumException {
    return false;
  }
}

Uint8List certifyDevice(
  JournalKeys keys, {
  required String deviceId,
  required Uint8List signPublicKey,
  required Uint8List boxPublicKey,
}) => signDetached(
  deviceCertificateBytes(
    deviceId: deviceId,
    signPublicKey: signPublicKey,
    boxPublicKey: boxPublicKey,
  ),
  keys.certifyingKeyPair,
);

bool verifyDeviceCertificate(
  Uint8List certifyingPublicKey, {
  required String deviceId,
  required Uint8List signPublicKey,
  required Uint8List boxPublicKey,
  required Uint8List certificate,
}) {
  try {
    return verifySignature(
      message: deviceCertificateBytes(
        deviceId: deviceId,
        signPublicKey: signPublicKey,
        boxPublicKey: boxPublicKey,
      ),
      signature: certificate,
      publicKey: certifyingPublicKey,
    );
  } on FormatException {
    return false;
  }
}

bool isCertifiedDevice(Uint8List certifyingPublicKey, DeviceInfo device) =>
    verifyDeviceCertificate(
      certifyingPublicKey,
      deviceId: device.deviceId,
      signPublicKey: device.signPublicKey,
      boxPublicKey: device.boxPublicKey,
      certificate: device.certificate,
    );

bool isCertifiedRegistration(
  Uint8List certifyingPublicKey,
  DeviceRegistration device,
) => verifyDeviceCertificate(
  certifyingPublicKey,
  deviceId: device.deviceId,
  signPublicKey: device.signPublicKey,
  boxPublicKey: device.boxPublicKey,
  certificate: device.certificate,
);

Uint8List certifyRecoveryKey(
  JournalKeys keys,
  Uint8List recoveryBoxPublicKey,
) => signDetached(
  recoveryCertificateBytes(recoveryBoxPublicKey),
  keys.certifyingKeyPair,
);

bool verifyRecoveryCertificate(
  Uint8List certifyingPublicKey, {
  required Uint8List recoveryBoxPublicKey,
  required Uint8List certificate,
}) => verifySignature(
  message: recoveryCertificateBytes(recoveryBoxPublicKey),
  signature: certificate,
  publicKey: certifyingPublicKey,
);

final class RotationRecipient {
  RotationRecipient({required this.recipient, required List<int> boxPublicKey})
    : boxPublicKey = frozenBytes(boxPublicKey);

  factory RotationRecipient.device(DeviceInfo device) => RotationRecipient(
    recipient: EpochKeyDelivery.deviceRecipient(device.deviceId),
    boxPublicKey: device.boxPublicKey,
  );

  factory RotationRecipient.recovery(Uint8List recoveryBoxPublicKey) =>
      RotationRecipient(
        recipient: EpochKeyDelivery.recoveryRecipient,
        boxPublicKey: recoveryBoxPublicKey,
      );

  final String recipient;
  final Uint8List boxPublicKey;
}

EpochRotation makeRotation({
  required int epoch,
  required Uint8List epochKey,
  required DeviceKeys signer,
  required List<RotationRecipient> recipients,
}) {
  final Box box = loadSodium().crypto.box;
  return EpochRotation(
    epoch: epoch,
    signerDeviceId: signer.deviceId,
    deliveries: <EpochKeyDelivery>[
      for (final RotationRecipient recipient in recipients)
        _delivery(
          epoch: epoch,
          recipient: recipient.recipient,
          sealed: box.seal(
            message: Uint8List.fromList(epochKey),
            publicKey: Uint8List.fromList(recipient.boxPublicKey),
          ),
          signer: signer,
        ),
    ],
  );
}

EpochKeyDelivery _delivery({
  required int epoch,
  required String recipient,
  required Uint8List sealed,
  required DeviceKeys signer,
}) => EpochKeyDelivery(
  recipient: recipient,
  sealed: sealed,
  signature: signer.sign(
    epochDeliveryBytes(
      epoch: epoch,
      recipient: recipient,
      sealed: sealed,
      signerDeviceId: signer.deviceId,
    ),
  ),
);

bool verifyDelivery({
  required int epoch,
  required String signerDeviceId,
  required EpochKeyDelivery delivery,
  required List<DeviceInfo> devices,
  required Uint8List certifyingPublicKey,
}) {
  final DeviceInfo? signer = _deviceById(devices, signerDeviceId);
  if (signer == null || !isCertifiedDevice(certifyingPublicKey, signer)) {
    return false;
  }
  try {
    return verifySignature(
      message: epochDeliveryBytes(
        epoch: epoch,
        recipient: delivery.recipient,
        sealed: delivery.sealed,
        signerDeviceId: signerDeviceId,
      ),
      signature: delivery.signature,
      publicKey: signer.signPublicKey,
    );
  } on FormatException {
    return false;
  }
}

Uint8List openDelivery(EpochKeyDelivery delivery, RawKeyPair boxKeyPair) {
  final Box box = loadSodium().crypto.box;
  if (delivery.sealed.length != box.sealBytes + journalKeyBytes) {
    throw const CryptoException('The epoch key delivery has the wrong size');
  }
  try {
    return frozenBytes(
      useSecureKey(
        boxKeyPair.secretKey,
        (SecureKey key) => box.sealOpen(
          cipherText: delivery.sealed,
          publicKey: Uint8List.fromList(boxKeyPair.publicKey),
          secretKey: key,
        ),
      ),
    );
  } on SodiumException catch (error) {
    throw CryptoException('The epoch key delivery could not be opened', error);
  }
}

Map<int, Uint8List> verifiedEpochKeys({
  required List<EpochRotation> rotations,
  required List<DeviceInfo> devices,
  required String recipient,
  required RawKeyPair boxKeyPair,
  required Uint8List certifyingPublicKey,
}) {
  final Map<int, Uint8List> keys = <int, Uint8List>{};
  for (final EpochRotation rotation in rotations) {
    if (rotation.epoch <= firstEpoch || keys.containsKey(rotation.epoch)) {
      continue;
    }
    for (final EpochKeyDelivery delivery in rotation.deliveries) {
      if (delivery.recipient != recipient ||
          !verifyDelivery(
            epoch: rotation.epoch,
            signerDeviceId: rotation.signerDeviceId,
            delivery: delivery,
            devices: devices,
            certifyingPublicKey: certifyingPublicKey,
          )) {
        continue;
      }
      try {
        keys[rotation.epoch] = openDelivery(delivery, boxKeyPair);
        break;
      } on CryptoException {
        continue;
      }
    }
  }
  return Map<int, Uint8List>.unmodifiable(keys);
}

List<DeviceInfo> certifiedDevices(
  Uint8List certifyingPublicKey,
  List<DeviceInfo> devices,
) => List<DeviceInfo>.unmodifiable(<DeviceInfo>[
  for (final DeviceInfo device in devices)
    if (isCertifiedDevice(certifyingPublicKey, device)) device,
]);

DeviceInfo? _deviceById(List<DeviceInfo> devices, String deviceId) {
  for (final DeviceInfo device in devices) {
    if (device.deviceId == deviceId) {
      return device;
    }
  }
  return null;
}

Uint8List sealSecretBox(Uint8List message, Uint8List key) {
  final SecretBox secretBox = loadSodium().crypto.secretBox;
  final Uint8List nonce = randomBytes(secretBox.nonceBytes);
  final Uint8List cipherText = useSecureKey(
    key,
    (SecureKey secureKey) =>
        secretBox.easy(message: message, nonce: nonce, key: secureKey),
  );
  final BytesBuilder builder = BytesBuilder(copy: false)
    ..add(nonce)
    ..add(cipherText);
  return builder.takeBytes();
}

Uint8List openSecretBox(Uint8List sealed, Uint8List key) {
  final SecretBox secretBox = loadSodium().crypto.secretBox;
  if (key.length != secretBox.keyBytes ||
      sealed.length < secretBox.nonceBytes + secretBox.macBytes) {
    throw const CryptoException('The sealed value is malformed');
  }
  try {
    return useSecureKey(
      key,
      (SecureKey secureKey) => secretBox.openEasy(
        cipherText: Uint8List.sublistView(sealed, secretBox.nonceBytes),
        nonce: Uint8List.sublistView(sealed, 0, secretBox.nonceBytes),
        key: secureKey,
      ),
    );
  } on SodiumException catch (error) {
    throw CryptoException('The sealed value could not be opened', error);
  }
}

Uint8List sealEpochOneCopy(
  Uint8List epochOneKey,
  Uint8List recoverySecretKey,
) => sealSecretBox(epochOneKey, recoverySecretKey);

Uint8List openEpochOneCopy(Uint8List copy, Uint8List recoverySecretKey) {
  final Uint8List key = openSecretBox(copy, recoverySecretKey);
  if (key.length != journalKeyBytes) {
    throw const CryptoException('The epoch-one copy holds no journal key');
  }
  return frozenBytes(key);
}

Uint8List sealPairingBundle(JournalKeys keys, Uint8List pairingKey) =>
    sealSecretBox(
      Uint8List.fromList(utf8.encode(jsonEncode(keys.toJson()))),
      pairingKey,
    );

Uint8List sealPairingBundleFor(
  JournalKeys keys,
  Uint8List pairingKey,
  Uint8List deviceBoxPublicKey,
) => frozenBytes(
  loadSodium().crypto.box.seal(
    message: sealPairingBundle(keys, pairingKey),
    publicKey: deviceBoxPublicKey,
  ),
);

JournalKeys openPairingBundleFor(
  Uint8List bundle,
  Uint8List pairingKey,
  RawKeyPair boxKeyPair,
) {
  final Box box = loadSodium().crypto.box;
  if (bundle.length <= box.sealBytes) {
    throw const CryptoException('The pairing bundle is not for this device');
  }
  final Uint8List inner;
  try {
    inner = useSecureKey(
      boxKeyPair.secretKey,
      (SecureKey key) => box.sealOpen(
        cipherText: bundle,
        publicKey: Uint8List.fromList(boxKeyPair.publicKey),
        secretKey: key,
      ),
    );
  } on SodiumException catch (error) {
    throw CryptoException('The pairing bundle is not for this device', error);
  }
  return openPairingBundle(inner, pairingKey);
}

JournalKeys openPairingBundle(Uint8List bundle, Uint8List pairingKey) {
  final Uint8List opened = openSecretBox(bundle, pairingKey);
  try {
    return JournalKeys.fromJson(decodeJsonObject(utf8.decode(opened)));
  } on FormatException catch (error) {
    throw CryptoException('The pairing bundle is malformed', error);
  } on ArgumentError catch (error) {
    throw CryptoException('The pairing bundle is malformed', error);
  }
}
