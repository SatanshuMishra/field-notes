import 'dart:convert';
import 'dart:typed_data';

import 'package:field_notes/data/crypto/journal_keys.dart';
import 'package:field_notes/data/crypto/sodium_loader.dart';
import 'package:sodium/sodium.dart';

const int deviceNameBlockBytes = 64;

Uint8List sealDeviceName(String name, String deviceId, JournalKeys keys) =>
    sealNameUnder(name, deviceId, keys.deviceNameKey);

String openDeviceName(Uint8List sealed, String deviceId, JournalKeys keys) =>
    openNameUnder(sealed, deviceId, keys.deviceNameKey);

Uint8List sealNameUnder(String name, String deviceId, Uint8List key) {
  final Sodium sodium = loadSodium();
  final Aead aead = sodium.crypto.aeadXChaCha20Poly1305IETF;
  final Uint8List nonce = randomBytes(aead.nonceBytes);
  final Uint8List cipherText = useSecureKey(
    key,
    (SecureKey secureKey) => aead.encrypt(
      message: sodium.pad(
        Uint8List.fromList(utf8.encode(name)),
        deviceNameBlockBytes,
      ),
      nonce: nonce,
      key: secureKey,
      additionalData: Uint8List.fromList(utf8.encode(deviceId)),
    ),
  );
  final BytesBuilder builder = BytesBuilder(copy: false)
    ..add(nonce)
    ..add(cipherText);
  return builder.takeBytes();
}

String openNameUnder(Uint8List sealed, String deviceId, Uint8List key) {
  final Sodium sodium = loadSodium();
  final Aead aead = sodium.crypto.aeadXChaCha20Poly1305IETF;
  if (sealed.length < aead.nonceBytes + aead.aBytes + deviceNameBlockBytes) {
    throw const CryptoException('The device name is malformed');
  }
  try {
    final Uint8List padded = useSecureKey(
      key,
      (SecureKey secureKey) => aead.decrypt(
        cipherText: Uint8List.sublistView(sealed, aead.nonceBytes),
        nonce: Uint8List.sublistView(sealed, 0, aead.nonceBytes),
        key: secureKey,
        additionalData: Uint8List.fromList(utf8.encode(deviceId)),
      ),
    );
    return utf8.decode(sodium.unpad(padded, deviceNameBlockBytes));
  } on SodiumException catch (error) {
    throw CryptoException('The device name could not be opened', error);
  } on FormatException catch (error) {
    throw CryptoException('The device name is malformed', error);
  }
}
