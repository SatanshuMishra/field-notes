import 'dart:convert';
import 'dart:typed_data';

import 'package:field_notes/data/crypto/journal_keys.dart';
import 'package:field_notes/data/crypto/sodium_loader.dart';
import 'package:sodium/sodium.dart';
import 'package:sync_protocol/sync_protocol.dart';

const int keyedNameBytes = 32;

final class KeyedNames {
  const KeyedNames(this.keys);

  final JournalKeys keys;

  String recordKey(String table, String rowId) =>
      _name(keys.recordNameKey, utf8.encode('$table\n$rowId'));

  String blobName(String sha256Id) =>
      _name(keys.blobNameKey, utf8.encode(sha256Id));

  static String _name(Uint8List key, Uint8List message) => encodeBase64Url(
    useSecureKey(
      key,
      (SecureKey secureKey) => loadSodium().crypto.genericHash(
        message: message,
        outLen: keyedNameBytes,
        key: secureKey,
      ),
    ),
  );
}
