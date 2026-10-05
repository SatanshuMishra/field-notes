import 'dart:typed_data';

import 'package:field_notes/data/crypto/sodium_loader.dart';
import 'package:sync_protocol/sync_protocol.dart';

const int journalKeyBytes = 32;
const int firstEpoch = 1;

const String recordContext = 'fnrecord';
const String fileContext = 'fnfile__';
const String recordNameContext = 'fnrecid_';
const String blobNameContext = 'fnblobnm';
const String certifyingContext = 'fncertif';
const String deviceNameContext = 'fnname__';

class CryptoException implements Exception {
  const CryptoException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'CryptoException: $message'
      : 'CryptoException: $message ($cause)';
}

class UnknownEpochException extends CryptoException {
  const UnknownEpochException(this.epoch)
    : super('No key is held for this epoch');

  final int epoch;

  @override
  String toString() => 'UnknownEpochException: epoch $epoch';
}

final class JournalKeys {
  JournalKeys({
    required Map<int, List<int>> epochKeys,
    required this.currentEpoch,
  }) : epochKeys = Map<int, Uint8List>.unmodifiable(<int, Uint8List>{
         for (final MapEntry<int, List<int>> entry in epochKeys.entries)
           entry.key: frozenBytes(entry.value),
       }) {
    if (!this.epochKeys.containsKey(firstEpoch)) {
      throw ArgumentError.value(epochKeys.keys, 'epochKeys', 'Lacks epoch 1');
    }
    if (!this.epochKeys.containsKey(currentEpoch)) {
      throw ArgumentError.value(currentEpoch, 'currentEpoch', 'Not held');
    }
    for (final MapEntry<int, Uint8List> entry in this.epochKeys.entries) {
      if (entry.key < firstEpoch || entry.value.length != journalKeyBytes) {
        throw ArgumentError.value(entry.key, 'epochKeys', 'Invalid epoch key');
      }
    }
  }

  factory JournalKeys.generate() => JournalKeys(
    epochKeys: <int, List<int>>{firstEpoch: newEpochKey()},
    currentEpoch: firstEpoch,
  );

  factory JournalKeys.fromJson(Map<String, Object?> json) {
    final Object? current = json['currentEpoch'];
    final Object? epochs = json['epochs'];
    if (current is! int || epochs is! Map<String, Object?>) {
      throw const FormatException('Invalid journal keys');
    }
    return JournalKeys(
      epochKeys: <int, List<int>>{
        for (final MapEntry<String, Object?> entry in epochs.entries)
          int.parse(entry.key): switch (entry.value) {
            final String encoded => decodeBase64Url(encoded),
            _ => throw const FormatException('Invalid journal keys'),
          },
      },
      currentEpoch: current,
    );
  }

  static Uint8List newEpochKey() => randomBytes(journalKeyBytes);

  final Map<int, Uint8List> epochKeys;
  final int currentEpoch;

  late final Map<int, Uint8List> _recordSubKeys = _deriveEach(recordContext);
  late final Map<int, Uint8List> _fileSubKeys = _deriveEach(fileContext);

  late final Uint8List recordNameKey = deriveKey(
    epochKey(firstEpoch),
    recordNameContext,
  );

  late final Uint8List blobNameKey = deriveKey(
    epochKey(firstEpoch),
    blobNameContext,
  );

  late final Uint8List deviceNameKey = deriveKey(
    epochKey(firstEpoch),
    deviceNameContext,
  );

  late final RawKeyPair certifyingKeyPair = signKeyPairFromSeed(
    deriveKey(epochKey(firstEpoch), certifyingContext),
  );

  Uint8List get certifyingPublicKey => certifyingKeyPair.publicKey;

  List<int> get epochs => epochKeys.keys.toList()..sort();

  bool hasEpoch(int epoch) => epochKeys.containsKey(epoch);

  Uint8List epochKey(int epoch) =>
      epochKeys[epoch] ?? (throw UnknownEpochException(epoch));

  Uint8List recordSubKey(int epoch) =>
      _recordSubKeys[epoch] ?? (throw UnknownEpochException(epoch));

  Uint8List fileSubKey(int epoch) =>
      _fileSubKeys[epoch] ?? (throw UnknownEpochException(epoch));

  JournalKeys withEpoch(int epoch, List<int> key) => JournalKeys(
    epochKeys: <int, List<int>>{...epochKeys, epoch: key},
    currentEpoch: epoch > currentEpoch ? epoch : currentEpoch,
  );

  JournalKeys withoutEpochsAbove(int epoch) {
    final int kept = epoch < firstEpoch ? firstEpoch : epoch;
    final List<int> remaining = <int>[
      for (final int held in epochs)
        if (held <= kept) held,
    ];
    return JournalKeys(
      epochKeys: <int, List<int>>{
        for (final int held in remaining) held: epochKeys[held]!,
      },
      currentEpoch: currentEpoch <= kept ? currentEpoch : remaining.last,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'currentEpoch': currentEpoch,
    'epochs': <String, Object?>{
      for (final int epoch in epochs)
        '$epoch': encodeBase64Url(epochKeys[epoch]!),
    },
  };

  Map<int, Uint8List> _deriveEach(String context) =>
      Map<int, Uint8List>.unmodifiable(<int, Uint8List>{
        for (final MapEntry<int, Uint8List> entry in epochKeys.entries)
          entry.key: deriveKey(entry.value, context),
      });
}
