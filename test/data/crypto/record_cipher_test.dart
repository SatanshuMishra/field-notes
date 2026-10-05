import 'dart:convert';
import 'dart:typed_data';

import 'package:field_notes/data/crypto/journal_keys.dart';
import 'package:field_notes/data/crypto/keyed_names.dart';
import 'package:field_notes/data/crypto/record_cipher.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _flipped(Uint8List bytes, int index) =>
    Uint8List.fromList(bytes)..[index] ^= 0x01;

void main() {
  test('an altered or moved envelope is refused', () {
    final JournalKeys keys = JournalKeys.generate();
    final RecordCipher cipher = RecordCipher(keys);
    final KeyedNames names = KeyedNames(keys);
    final String recordKey = names.recordKey('entries', '01J9ZQ4M8V7C2X');
    final String otherKey = names.recordKey('entries', '01J9ZQ4M8V7C2Y');
    final Uint8List plain = Uint8List.fromList(
      utf8.encode('{"text":"A walk by the river","mood":"sunny"}'),
    );

    final Uint8List envelope = cipher.seal(plain, recordKey, 1);

    expect(cipher.open(envelope, recordKey, 1), plain);
    for (final int index in <int>[0, 23, 24, 100, envelope.length - 1]) {
      expect(
        () => cipher.open(_flipped(envelope, index), recordKey, 1),
        throwsA(isA<CryptoException>()),
        reason: 'byte $index flipped',
      );
    }
    expect(
      () => cipher.open(envelope, otherKey, 1),
      throwsA(isA<CryptoException>()),
    );
    expect(
      () => cipher.open(
        Uint8List.sublistView(envelope, 0, envelope.length - 1),
        recordKey,
        1,
      ),
      throwsA(isA<CryptoException>()),
    );
    final JournalKeys rotated = keys.withEpoch(2, JournalKeys.newEpochKey());
    expect(
      () => RecordCipher(rotated).open(envelope, recordKey, 2),
      throwsA(isA<CryptoException>()),
    );
    expect(RecordCipher(rotated).open(envelope, recordKey, 1), plain);
  });

  test('an envelope under an epoch this device lacks names the epoch', () {
    final JournalKeys keys = JournalKeys.generate();
    final JournalKeys later = keys.withEpoch(3, JournalKeys.newEpochKey());
    final String recordKey = KeyedNames(keys).recordKey('days', '2026-09-29');
    final Uint8List envelope = RecordCipher(later)
        .seal(Uint8List.fromList(utf8.encode('{}')), recordKey, 3);

    expect(
      () => RecordCipher(keys).open(envelope, recordKey, 3),
      throwsA(
        isA<UnknownEpochException>().having(
          (UnknownEpochException error) => error.epoch,
          'epoch',
          3,
        ),
      ),
    );
  });

  test('envelopes hide sizes inside power-of-two buckets from 256 bytes', () {
    final JournalKeys keys = JournalKeys.generate();
    final RecordCipher cipher = RecordCipher(keys);
    const String recordKey = 'record';
    final Map<int, int> buckets = <int, int>{
      0: 256,
      1: 256,
      255: 256,
      256: 512,
      700: 1024,
      5000: 8192,
    };

    for (final MapEntry<int, int> bucket in buckets.entries) {
      final Uint8List plain = Uint8List(bucket.key);
      final Uint8List envelope = cipher.seal(plain, recordKey, 1);
      expect(envelope.length, 24 + bucket.value + 16, reason: '${bucket.key}');
      expect(cipher.open(envelope, recordKey, 1), plain);
    }
  });
}
