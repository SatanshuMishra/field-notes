import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:field_notes/data/crypto/journal_keys.dart';
import 'package:field_notes/data/crypto/keyed_names.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sync_protocol/sync_protocol.dart';

void main() {
  test('names differ from plaintext hashes and between journals', () {
    final JournalKeys mine = JournalKeys.generate();
    final JournalKeys theirs = JournalKeys.generate();
    final Digest digest = sha256.convert(utf8.encode('the same photo bytes'));
    final String sha256Id = digest.toString();
    const String entryId = '01J9ZQ4M8V7C2XKQ5W3D0E6F1G';

    final String blobName = KeyedNames(mine).blobName(sha256Id);
    final String recordKey = KeyedNames(mine).recordKey('entries', entryId);

    expect(blobName, hasLength(43));
    expect(recordKey, hasLength(43));
    expect(blobName, isNot(sha256Id));
    expect(blobName, isNot(encodeBase64Url(digest.bytes)));
    expect(blobName, isNot(contains(sha256Id.substring(0, 12))));
    expect(recordKey, isNot(entryId));
    expect(recordKey, isNot(contains(entryId)));

    expect(KeyedNames(theirs).blobName(sha256Id), isNot(blobName));
    expect(KeyedNames(theirs).recordKey('entries', entryId), isNot(recordKey));

    final JournalKeys rotated = mine.withEpoch(2, JournalKeys.newEpochKey());
    expect(KeyedNames(rotated).blobName(sha256Id), blobName);
    expect(KeyedNames(rotated).recordKey('entries', entryId), recordKey);
  });

  test('a record key depends on its table and its id', () {
    final KeyedNames names = KeyedNames(JournalKeys.generate());

    expect(names.recordKey('entries', 'a'), names.recordKey('entries', 'a'));
    expect(
      names.recordKey('entries', 'a'),
      isNot(names.recordKey('days', 'a')),
    );
    expect(
      names.recordKey('entries', 'a'),
      isNot(names.recordKey('entries', 'b')),
    );
    expect(
      names.recordKey('entries', 'a'),
      isNot(names.blobName('entries\na')),
    );
  });
}
