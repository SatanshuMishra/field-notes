import 'dart:typed_data';

import 'package:field_notes/data/crypto/bip39_english.dart';
import 'package:field_notes/data/crypto/recovery_phrase.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _hex(String hex) => Uint8List.fromList(<int>[
  for (int index = 0; index < hex.length; index += 2)
    int.parse(hex.substring(index, index + 2), radix: 16),
]);

String _mixedCase(String word, int index) => index.isEven
    ? word.toUpperCase()
    : '${word[0].toUpperCase()}${word.substring(1)}';

void main() {
  test('a seed survives the phrase round trip', () {
    final Uint8List seed = newRecoverySeed();

    final List<String> words = recoveryWords(seed);

    expect(words, hasLength(12));
    for (final String word in words) {
      expect(bip39English, contains(word));
    }
    expect(decodeRecoveryPhrase(words.join(' ')), seed);
    final String typed = <String>[
      for (int index = 0; index < words.length; index++)
        _mixedCase(words[index], index),
    ].join('   ');
    expect(decodeRecoveryPhrase('  \n$typed \t '), seed);
  });

  test('the phrase follows the BIP39 English test vectors', () {
    final Map<String, String> vectors = <String, String>{
      '00000000000000000000000000000000':
          'abandon abandon abandon abandon abandon abandon abandon abandon '
          'abandon abandon abandon about',
      '7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f':
          'legal winner thank year wave sausage worth useful legal winner '
          'thank yellow',
      '80808080808080808080808080808080':
          'letter advice cage absurd amount doctor acoustic avoid letter '
          'advice cage above',
      'ffffffffffffffffffffffffffffffff':
          'zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo wrong',
    };

    expect(bip39English, hasLength(2048));
    for (final MapEntry<String, String> vector in vectors.entries) {
      expect(encodeRecoveryPhrase(_hex(vector.key)), vector.value);
      expect(decodeRecoveryPhrase(vector.value), _hex(vector.key));
    }
  });

  test('a bad word or checksum is rejected', () {
    final List<String> words = recoveryWords(newRecoverySeed());

    final List<String> unknown = <String>[...words]..[3] = 'notaword';
    expect(
      () => decodeRecoveryPhrase(unknown.join(' ')),
      throwsA(
        isA<RecoveryPhraseException>()
            .having(
              (RecoveryPhraseException error) => error.problem,
              'problem',
              RecoveryPhraseProblem.unknownWord,
            )
            .having(
              (RecoveryPhraseException error) => error.word,
              'word',
              'notaword',
            ),
      ),
    );

    final int lastIndex = bip39English.indexOf(words.last);
    final List<String> badChecksum = <String>[...words]
      ..[11] = bip39English[lastIndex ^ 1];
    expect(
      () => decodeRecoveryPhrase(badChecksum.join(' ')),
      throwsA(
        isA<RecoveryPhraseException>().having(
          (RecoveryPhraseException error) => error.problem,
          'problem',
          RecoveryPhraseProblem.badChecksum,
        ),
      ),
    );
    expect(
      () => decodeRecoveryPhrase(List<String>.filled(12, 'abandon').join(' ')),
      throwsA(isA<RecoveryPhraseException>()),
    );
    expect(
      () => decodeRecoveryPhrase(words.take(11).join(' ')),
      throwsA(
        isA<RecoveryPhraseException>().having(
          (RecoveryPhraseException error) => error.problem,
          'problem',
          RecoveryPhraseProblem.wrongLength,
        ),
      ),
    );
  });

  test('a seed always derives the same recovery keys', () {
    final Uint8List seed = newRecoverySeed();
    final RecoveryKeys first = RecoveryKeys.fromSeed(seed);
    final RecoveryKeys again = RecoveryKeys.fromSeed(
      decodeRecoveryPhrase(encodeRecoveryPhrase(seed)),
    );
    final RecoveryKeys other = RecoveryKeys.fromSeed(newRecoverySeed());

    expect(again.secretKey, first.secretKey);
    expect(again.boxKeyPair.publicKey, first.boxKeyPair.publicKey);
    expect(again.signKeyPair.publicKey, first.signKeyPair.publicKey);
    expect(first.secretKey, hasLength(32));
    expect(first.boxKeyPair.publicKey, hasLength(32));
    expect(first.signKeyPair.publicKey, hasLength(32));
    expect(other.secretKey, isNot(first.secretKey));
    expect(other.boxKeyPair.publicKey, isNot(first.boxKeyPair.publicKey));
    expect(other.signKeyPair.publicKey, isNot(first.signKeyPair.publicKey));
    expect(first.publicKeys.boxPublicKey, first.boxKeyPair.publicKey);
    expect(first.publicKeys.signPublicKey, first.signKeyPair.publicKey);
  });
}
