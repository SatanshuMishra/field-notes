import 'dart:convert';
import 'dart:math';

import 'package:field_notes/domain/services/note_limits.dart';
import 'package:flutter_test/flutter_test.dart';

String _randomText(Random random, int length) {
  const List<int> awkward = <int>[
    0x00,
    0x08,
    0x09,
    0x0a,
    0x0c,
    0x0d,
    0x1f,
    0x22,
    0x5c,
    0x7f,
    0x80,
    0x7ff,
    0x800,
    0x2028,
    0xd7ff,
    0xd800,
    0xdbff,
    0xdc00,
    0xdfff,
    0xe000,
    0xfffd,
    0xffff,
  ];
  return String.fromCharCodes(<int>[
    for (int index = 0; index < length; index++)
      random.nextBool()
          ? awkward[random.nextInt(awkward.length)]
          : random.nextInt(0x10000),
  ]);
}

void main() {
  test('the synced size of a note matches its encoded size exactly', () {
    final Random random = Random(20261006);
    for (int round = 0; round < 400; round++) {
      final String text = _randomText(random, random.nextInt(200));
      expect(
        noteSyncedBytes(text),
        utf8.encode(jsonEncode(text)).length,
        reason: text.codeUnits.toString(),
      );
    }
    for (final String text in <String>['', 'plain words', '"quoted"\n', '😀']) {
      expect(noteSyncedBytes(text), utf8.encode(jsonEncode(text)).length);
    }
  });

  test('a note fits when it is within both the character and byte limits', () {
    expect(noteFitsSync('a' * maxNoteCharacters), isTrue);
    expect(noteFitsSync('a' * (maxNoteCharacters + 1)), isFalse);
    expect(noteFitsSync('\u0001' * 600000), isFalse);
    expect(noteFitsSync('界' * maxNoteCharacters), isTrue);
  });
}
