import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:field_notes/data/crypto/sodium_loader.dart';
import 'package:sodium/sodium.dart';

const String updatePublicKeyBase64 = String.fromEnvironment(
  'FIELD_NOTES_UPDATE_PUBLIC_KEY',
);

const int updatePublicKeyBytes = 32;
const int updateSignatureBytes = 64;

final RegExp _digestPattern = RegExp(r'^[0-9a-f]{64}$');
final RegExp _sumsLine = RegExp(r'^([0-9A-Fa-f]{64}) [ *](.+)$');

final class ReleaseVerifier {
  ReleaseVerifier(List<int> publicKey) : _publicKey = _checkedKey(publicKey);

  static ReleaseVerifier? fromBase64(String text) {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final Uint8List bytes;
    try {
      bytes = base64.decode(trimmed);
    } on FormatException {
      return null;
    }
    if (bytes.length != updatePublicKeyBytes) {
      return null;
    }
    return ReleaseVerifier(bytes);
  }

  static Uint8List _checkedKey(List<int> publicKey) {
    if (publicKey.length != updatePublicKeyBytes) {
      throw ArgumentError.value(
        publicKey.length,
        'publicKey',
        'An update key holds exactly $updatePublicKeyBytes bytes',
      );
    }
    return frozenBytes(publicKey);
  }

  final Uint8List _publicKey;

  bool sumsAreSigned(List<int> sums, String signatureText) {
    final Uint8List signature;
    try {
      signature = base64.decode(signatureText.trim());
    } on FormatException {
      return false;
    }
    if (signature.length != updateSignatureBytes) {
      return false;
    }
    try {
      return loadSodium().crypto.sign.verifyDetached(
        message: Uint8List.fromList(sums),
        signature: signature,
        publicKey: _publicKey,
      );
    } on SodiumException {
      return false;
    }
  }

  String? expectedDigest(String sumsText, String fileName) {
    String? found;
    for (final String raw in const LineSplitter().convert(sumsText)) {
      final RegExpMatch? match = _sumsLine.firstMatch(raw);
      if (match == null || match.group(2) != fileName) {
        continue;
      }
      final String digest = match.group(1)!.toLowerCase();
      if (found != null && found != digest) {
        return null;
      }
      found = digest;
    }
    return found;
  }

  Future<bool> fileMatches(File file, String digest) async {
    final String expected = digest.toLowerCase();
    if (!_digestPattern.hasMatch(expected)) {
      return false;
    }
    try {
      final Digest actual = await sha256.bind(file.openRead()).first;
      return actual.toString() == expected;
    } on FileSystemException {
      return false;
    }
  }

  Future<bool> verify({
    required List<int> sums,
    required String signature,
    required String fileName,
    required File file,
  }) async {
    if (!sumsAreSigned(sums, signature)) {
      return false;
    }
    final String sumsText;
    try {
      sumsText = utf8.decode(sums);
    } on FormatException {
      return false;
    }
    final String? digest = expectedDigest(sumsText, fileName);
    if (digest == null) {
      return false;
    }
    return fileMatches(file, digest);
  }
}
