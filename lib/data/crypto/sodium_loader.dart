import 'dart:typed_data';

import 'package:sodium/sodium.dart';
import 'package:sodium/sodium.ffi.dart' as sodium_ffi;

final Sodium _sodium = sodium_ffi.SodiumInit.init();

Sodium loadSodium() => _sodium;

const int derivedKeyBytes = 32;

Uint8List frozenBytes(List<int> bytes) =>
    Uint8List.fromList(bytes).asUnmodifiableView();

final class RawKeyPair {
  RawKeyPair({required List<int> publicKey, required List<int> secretKey})
    : publicKey = frozenBytes(publicKey),
      secretKey = frozenBytes(secretKey);

  factory RawKeyPair.take(KeyPair pair) {
    try {
      return RawKeyPair(
        publicKey: pair.publicKey,
        secretKey: pair.secretKey.extractBytes(),
      );
    } finally {
      pair.dispose();
    }
  }

  final Uint8List publicKey;
  final Uint8List secretKey;
}

T useSecureKey<T>(List<int> bytes, T Function(SecureKey key) use) {
  final SecureKey key = SecureKey.fromList(_sodium, Uint8List.fromList(bytes));
  try {
    return use(key);
  } finally {
    key.dispose();
  }
}

Future<T> useSecureKeyAsync<T>(
  List<int> bytes,
  Future<T> Function(SecureKey key) use,
) async {
  final SecureKey key = SecureKey.fromList(_sodium, Uint8List.fromList(bytes));
  try {
    return await use(key);
  } finally {
    key.dispose();
  }
}

Uint8List takeKeyBytes(SecureKey key) {
  try {
    return frozenBytes(key.extractBytes());
  } finally {
    key.dispose();
  }
}

Uint8List deriveKey(
  List<int> masterKey,
  String context, {
  int length = derivedKeyBytes,
}) => useSecureKey(
  masterKey,
  (SecureKey master) => takeKeyBytes(
    _sodium.crypto.kdf.deriveFromKey(
      masterKey: master,
      context: context,
      subkeyId: BigInt.one,
      subkeyLen: length,
    ),
  ),
);

RawKeyPair signKeyPairFromSeed(List<int> seed) => useSecureKey(
  seed,
  (SecureKey key) => RawKeyPair.take(_sodium.crypto.sign.seedKeyPair(key)),
);

RawKeyPair boxKeyPairFromSeed(List<int> seed) => useSecureKey(
  seed,
  (SecureKey key) => RawKeyPair.take(_sodium.crypto.box.seedKeyPair(key)),
);

Uint8List randomBytes(int length) => _sodium.randombytes.buf(length);

bool sameBytes(List<int> a, List<int> b) =>
    a.length == b.length &&
    _sodium.memcmp(Uint8List.fromList(a), Uint8List.fromList(b));
