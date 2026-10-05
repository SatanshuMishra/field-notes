import 'dart:convert';
import 'dart:typed_data';

import 'package:field_notes/data/crypto/journal_keys.dart';
import 'package:field_notes/data/crypto/sodium_loader.dart';
import 'package:sodium/sodium.dart';

const int smallestRecordBucket = 256;

int recordBucketFor(int length) {
  int bucket = smallestRecordBucket;
  while (bucket <= length) {
    bucket *= 2;
  }
  return bucket;
}

Uint8List recordAssociatedData(String recordKey, int epoch) {
  final BytesBuilder builder = BytesBuilder(copy: false)
    ..add(utf8.encode(recordKey))
    ..add((ByteData(4)..setUint32(0, epoch, Endian.big)).buffer.asUint8List());
  return builder.takeBytes();
}

final class RecordCipher {
  const RecordCipher(this.keys);

  final JournalKeys keys;

  Uint8List seal(Uint8List bytes, String recordKey, int epoch) {
    final Sodium sodium = loadSodium();
    final Aead aead = _aead(sodium);
    final Uint8List padded = sodium.pad(bytes, recordBucketFor(bytes.length));
    final Uint8List nonce = randomBytes(aead.nonceBytes);
    final Uint8List cipherText = useSecureKey(
      keys.recordSubKey(epoch),
      (SecureKey key) => aead.encrypt(
        message: padded,
        nonce: nonce,
        key: key,
        additionalData: recordAssociatedData(recordKey, epoch),
      ),
    );
    final BytesBuilder envelope = BytesBuilder(copy: false)
      ..add(nonce)
      ..add(cipherText);
    return envelope.takeBytes();
  }

  Uint8List open(Uint8List envelope, String recordKey, int epoch) {
    final Uint8List subKey = keys.recordSubKey(epoch);
    final Sodium sodium = loadSodium();
    final Aead aead = _aead(sodium);
    if (envelope.length < aead.nonceBytes + aead.aBytes + 1) {
      throw const CryptoException('The record envelope is too short');
    }
    try {
      final Uint8List padded = useSecureKey(
        subKey,
        (SecureKey key) => aead.decrypt(
          cipherText: Uint8List.sublistView(envelope, aead.nonceBytes),
          nonce: Uint8List.sublistView(envelope, 0, aead.nonceBytes),
          key: key,
          additionalData: recordAssociatedData(recordKey, epoch),
        ),
      );
      return sodium.unpad(padded, padded.length);
    } on SodiumException catch (error) {
      throw CryptoException('The record could not be opened', error);
    }
  }

  static Aead _aead(Sodium sodium) => sodium.crypto.aeadXChaCha20Poly1305IETF;
}
