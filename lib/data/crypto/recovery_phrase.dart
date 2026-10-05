import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:field_notes/data/crypto/bip39_english.dart';
import 'package:field_notes/data/crypto/sodium_loader.dart';
import 'package:sodium/sodium.dart';

const int recoverySeedBytes = 16;
const int recoveryWordCount = 12;
const int bitsPerWord = 11;

const String recoveryMasterLabel = 'field-notes-recovery-v1';
const String recoverySecretContext = 'fnrcsecr';
const String recoveryBoxContext = 'fnrcbox_';
const String recoverySignContext = 'fnrcsign';

enum RecoveryPhraseProblem { wrongLength, unknownWord, badChecksum }

class RecoveryPhraseException implements Exception {
  const RecoveryPhraseException(this.problem, [this.word]);

  final RecoveryPhraseProblem problem;
  final String? word;

  @override
  String toString() => word == null
      ? 'RecoveryPhraseException: ${problem.name}'
      : 'RecoveryPhraseException: ${problem.name} ($word)';
}

final Map<String, int> _wordIndex = Map<String, int>.unmodifiable(<String, int>{
  for (int index = 0; index < bip39English.length; index++)
    bip39English[index]: index,
});

List<String> normalizeWords(String phrase) => <String>[
  for (final String word in phrase.trim().toLowerCase().split(RegExp(r'\s+')))
    if (word.isNotEmpty) word,
];

bool isWordListWord(String word) => _wordIndex.containsKey(word);

List<String> wordsFromBits(BigInt value, int bitLength) {
  if (bitLength % bitsPerWord != 0) {
    throw ArgumentError.value(bitLength, 'bitLength', 'Not whole words');
  }
  final int count = bitLength ~/ bitsPerWord;
  final BigInt mask = BigInt.from((1 << bitsPerWord) - 1);
  return List<String>.unmodifiable(<String>[
    for (int index = 0; index < count; index++)
      bip39English[((value >> ((count - 1 - index) * bitsPerWord)) & mask)
          .toInt()],
  ]);
}

BigInt bitsFromWords(List<String> words) {
  BigInt value = BigInt.zero;
  for (final String word in words) {
    final int? index = _wordIndex[word];
    if (index == null) {
      throw RecoveryPhraseException(RecoveryPhraseProblem.unknownWord, word);
    }
    value = (value << bitsPerWord) | BigInt.from(index);
  }
  return value;
}

BigInt bigIntFromBytes(List<int> bytes) {
  BigInt value = BigInt.zero;
  for (final int byte in bytes) {
    value = (value << 8) | BigInt.from(byte);
  }
  return value;
}

Uint8List bytesFromBigInt(BigInt value, int length) {
  final BigInt mask = BigInt.from(0xff);
  return Uint8List.fromList(<int>[
    for (int index = length - 1; index >= 0; index--)
      ((value >> (index * 8)) & mask).toInt(),
  ]);
}

int _checksumOf(List<int> seed) => sha256.convert(seed).bytes.first >> 4;

Uint8List newRecoverySeed() => randomBytes(recoverySeedBytes);

List<String> recoveryWords(Uint8List seed) {
  if (seed.length != recoverySeedBytes) {
    throw ArgumentError.value(seed.length, 'seed', 'Not 16 bytes');
  }
  return wordsFromBits(
    (bigIntFromBytes(seed) << 4) | BigInt.from(_checksumOf(seed)),
    recoveryWordCount * bitsPerWord,
  );
}

String encodeRecoveryPhrase(Uint8List seed) => recoveryWords(seed).join(' ');

Uint8List decodeRecoveryPhrase(String phrase) {
  final List<String> words = normalizeWords(phrase);
  if (words.length != recoveryWordCount) {
    throw const RecoveryPhraseException(RecoveryPhraseProblem.wrongLength);
  }
  final BigInt value = bitsFromWords(words);
  final Uint8List seed = bytesFromBigInt(value >> 4, recoverySeedBytes);
  if ((value & BigInt.from(0xf)).toInt() != _checksumOf(seed)) {
    throw const RecoveryPhraseException(RecoveryPhraseProblem.badChecksum);
  }
  return seed;
}

final class RecoveryPublicKeys {
  RecoveryPublicKeys({
    required List<int> signPublicKey,
    required List<int> boxPublicKey,
  }) : signPublicKey = frozenBytes(signPublicKey),
       boxPublicKey = frozenBytes(boxPublicKey);

  final Uint8List signPublicKey;
  final Uint8List boxPublicKey;
}

final class RecoveryKeys {
  RecoveryKeys._({
    required this.secretKey,
    required this.boxKeyPair,
    required this.signKeyPair,
  });

  factory RecoveryKeys.fromSeed(Uint8List seed) {
    if (seed.length != recoverySeedBytes) {
      throw ArgumentError.value(seed.length, 'seed', 'Not 16 bytes');
    }
    final Uint8List master = useSecureKey(
      seed,
      (SecureKey key) => loadSodium().crypto.genericHash(
        message: Uint8List.fromList(utf8.encode(recoveryMasterLabel)),
        outLen: derivedKeyBytes,
        key: key,
      ),
    );
    return RecoveryKeys._(
      secretKey: deriveKey(master, recoverySecretContext),
      boxKeyPair: boxKeyPairFromSeed(deriveKey(master, recoveryBoxContext)),
      signKeyPair: signKeyPairFromSeed(deriveKey(master, recoverySignContext)),
    );
  }

  final Uint8List secretKey;
  final RawKeyPair boxKeyPair;
  final RawKeyPair signKeyPair;

  RecoveryPublicKeys get publicKeys => RecoveryPublicKeys(
    signPublicKey: signKeyPair.publicKey,
    boxPublicKey: boxKeyPair.publicKey,
  );
}
