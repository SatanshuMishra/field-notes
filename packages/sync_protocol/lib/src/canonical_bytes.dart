import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'messages.dart';

Uint8List sessionChallengeBytes({
  required String challengeId,
  required String nonce,
  required String deviceId,
}) => _canonicalBytes('field-notes-session-v1', <String>[
  challengeId,
  nonce,
  deviceId,
]);

Uint8List restoreChallengeBytes({
  required String challengeId,
  required String nonce,
  required Uint8List recoverySignPublicKey,
}) => _canonicalBytes('field-notes-restore-v1', <String>[
  challengeId,
  nonce,
  encodeBase64Url(recoverySignPublicKey),
]);

Uint8List deviceCertificateBytes({
  required String deviceId,
  required Uint8List signPublicKey,
  required Uint8List boxPublicKey,
}) => _canonicalBytes('field-notes-device-v1', <String>[
  deviceId,
  encodeBase64Url(signPublicKey),
  encodeBase64Url(boxPublicKey),
]);

Uint8List recoveryCertificateBytes(Uint8List recoveryBoxPublicKey) =>
    _canonicalBytes('field-notes-recovery-v1', <String>[
      encodeBase64Url(recoveryBoxPublicKey),
    ]);

Uint8List epochDeliveryBytes({
  required int epoch,
  required String recipient,
  required Uint8List sealed,
  required String signerDeviceId,
}) => _canonicalBytes('field-notes-epoch-v1', <String>[
  '$epoch',
  recipient,
  encodeBase64Url(sealed),
  signerDeviceId,
]);

Uint8List pairingJoinBytes({
  required String mailboxId,
  required DeviceRegistration device,
}) => _canonicalBytes('field-notes-pairing-v1', <String>[
  mailboxId,
  device.deviceId,
  encodeBase64Url(device.signPublicKey),
  encodeBase64Url(device.boxPublicKey),
  encodeBase64Url(device.certificate),
  encodeBase64Url(device.encryptedName),
]);

String mailboxTokenHash(String token) =>
    encodeBase64Url(sha256.convert(utf8.encode(token)).bytes);

Uint8List _canonicalBytes(String prefix, List<String> fields) {
  for (final String field in fields) {
    if (field.contains('\n')) {
      throw const FormatException('A signed field holds a line break');
    }
  }
  return utf8.encode(<String>[prefix, ...fields].join('\n'));
}
