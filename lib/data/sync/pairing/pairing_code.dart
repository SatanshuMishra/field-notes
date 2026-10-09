import 'dart:convert';
import 'dart:typed_data';

import 'package:field_notes/data/crypto/recovery_phrase.dart';
import 'package:field_notes/data/crypto/sodium_loader.dart';
import 'package:field_notes/data/sync/relay_address.dart';
import 'package:sodium/sodium.dart';
import 'package:sync_protocol/sync_protocol.dart';

const int pairingSecretBytes = 11;
const int pairingWordCount = 8;
const String pairingScheme = 'fieldnotes-pair';
const Duration pairingLifetime = Duration(minutes: 10);

const String _rootLabel = 'field-notes-pairing-v1';
const String _mailboxIdLabel = 'mailbox-id';
const String _mailboxTokenLabel = 'mailbox-token';
const String _pairingKeyLabel = 'pairing-key';
const String _comparisonLabel = 'comparison-number';
const int _comparisonBytes = 16;
final BigInt _comparisonRange = BigInt.from(1000000);

class PairingCodeException implements Exception {
  const PairingCodeException(this.message);

  final String message;

  @override
  String toString() => 'PairingCodeException: $message';
}

class PlainHttpPairingCodeException extends PairingCodeException {
  const PlainHttpPairingCodeException()
    : super('The QR code names a plain HTTP address');
}

final class PairingCode {
  PairingCode({required List<int> secret, this.relayUrl})
    : secret = frozenBytes(secret) {
    if (this.secret.length != pairingSecretBytes) {
      throw ArgumentError.value(secret.length, 'secret', 'Not 11 bytes');
    }
  }

  factory PairingCode.generate({Uri? relayUrl}) =>
      PairingCode(secret: randomBytes(pairingSecretBytes), relayUrl: relayUrl);

  factory PairingCode.parse(String input) {
    final String trimmed = input.trim();
    if (trimmed.toLowerCase().startsWith('$pairingScheme:')) {
      return _parsePayload(trimmed.substring(pairingScheme.length + 1));
    }
    final List<String> words = normalizeWords(trimmed);
    if (words.length != pairingWordCount) {
      throw const PairingCodeException('A pairing code has 8 words');
    }
    try {
      return PairingCode(
        secret: bytesFromBigInt(bitsFromWords(words), pairingSecretBytes),
      );
    } on RecoveryPhraseException {
      throw const PairingCodeException('A word is not in the word list');
    }
  }

  final Uint8List secret;
  final Uri? relayUrl;

  late final Uint8List _root = loadSodium().crypto.genericHash(
    message: Uint8List.fromList(<int>[...utf8.encode(_rootLabel), ...secret]),
    outLen: 32,
  );

  late final String mailboxId = encodeBase64Url(
    _derive(_mailboxIdLabel, syncIdByteLength),
  );

  late final String mailboxToken = encodeBase64Url(
    _derive(_mailboxTokenLabel, 32),
  );

  late final Uint8List pairingKey = frozenBytes(_derive(_pairingKeyLabel, 32));

  List<String> get words =>
      wordsFromBits(bigIntFromBytes(secret), pairingWordCount * bitsPerWord);

  String get phrase => words.join(' ');

  String get qrPayload {
    final Uri? url = relayUrl;
    if (url == null) {
      throw StateError('A QR code needs the relay address');
    }
    return '$pairingScheme:$url#${encodeBase64Url(secret)}';
  }

  PairingCode withRelayUrl(Uri url) =>
      PairingCode(secret: secret, relayUrl: url);

  Uint8List authenticatorFor(DeviceRegistration device) => _keyedHash(
    pairingKey,
    pairingJoinBytes(mailboxId: mailboxId, device: device),
    32,
  );

  String comparisonFor(DeviceRegistration device) {
    final BigInt value = bigIntFromBytes(
      _keyedHash(pairingKey, <int>[
        ...utf8.encode(_comparisonLabel),
        ...pairingJoinBytes(mailboxId: mailboxId, device: device),
      ], _comparisonBytes),
    );
    final String digits = (value % _comparisonRange).toString().padLeft(6, '0');
    return '${digits.substring(0, 3)} ${digits.substring(3)}';
  }

  bool authenticates(PairingJoinRequest join) {
    try {
      return sameBytes(authenticatorFor(join.device), join.authenticator);
    } on FormatException {
      return false;
    }
  }

  Uint8List _derive(String label, int length) =>
      _keyedHash(_root, utf8.encode(label), length);

  static Uint8List _keyedHash(List<int> key, List<int> message, int length) =>
      useSecureKey(
        key,
        (SecureKey secureKey) => loadSodium().crypto.genericHash(
          message: Uint8List.fromList(message),
          outLen: length,
          key: secureKey,
        ),
      );

  static PairingCode _parsePayload(String payload) {
    final int hash = payload.lastIndexOf('#');
    if (hash <= 0) {
      throw const PairingCodeException('The QR code has no secret');
    }
    final Uri? url = Uri.tryParse(payload.substring(0, hash));
    if (url != null && isPlainHttpRelayAddress(url)) {
      throw const PlainHttpPairingCodeException();
    }
    if (url == null || !isUsableRelayAddress(url)) {
      throw const PairingCodeException('The QR code has no usable address');
    }
    try {
      final Uint8List secret = decodeBase64Url(payload.substring(hash + 1));
      if (secret.length != pairingSecretBytes) {
        throw const PairingCodeException('The QR code secret is malformed');
      }
      return PairingCode(secret: secret, relayUrl: url);
    } on FormatException {
      throw const PairingCodeException('The QR code secret is malformed');
    }
  }
}
