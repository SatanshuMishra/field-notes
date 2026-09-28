import 'dart:math';

import 'package:field_notes/features/note_engine/document/change_set.dart';
import 'package:flutter_test/flutter_test.dart';

const List<String> _pieces = <String>[
  'a',
  'b',
  'Z',
  ' ',
  '#',
  '\n',
  '\r\n',
  '\u00e9',
  '\u{1F44D}\u{1F3FD}',
  '\u65e5\u672c',
];

String _randomText(Random random, int maxLength) {
  final int target = random.nextInt(maxLength + 1);
  final StringBuffer buffer = StringBuffer();
  while (buffer.length < target) {
    buffer.write(_pieces[random.nextInt(_pieces.length)]);
  }
  final String text = buffer.toString();
  return text.length > maxLength ? text.substring(0, maxLength) : text;
}

ChangeSet _randomChangeSet(Random random, int length) {
  final int count = random.nextInt(5);
  final List<int> offsets = <int>[
    for (int i = 0; i < count * 2; i++) random.nextInt(length + 1),
  ]..sort();
  return ChangeSet(
    length: length,
    replacements: <TextReplacement>[
      for (int i = 0; i < count; i++)
        TextReplacement(
          offsets[i * 2],
          offsets[i * 2 + 1],
          _randomText(random, 6),
        ),
    ],
  );
}

void main() {
  final ChangeSet e2 = ChangeSet(
    length: 11,
    replacements: const <TextReplacement>[TextReplacement(5, 5, 'abc')],
  );

  test('applying then inverting restores the original string', () {
    expect(e2.apply('hello world'), 'helloabc world');
    final ChangeSet inverse = e2.invert('hello world');
    expect(
      inverse,
      ChangeSet(
        length: 14,
        replacements: const <TextReplacement>[TextReplacement(5, 8, '')],
      ),
    );
    expect(inverse.apply('helloabc world'), 'hello world');

    final Random random = Random(20260923);
    for (int i = 0; i < 1000; i++) {
      final String document = _randomText(random, 80);
      final ChangeSet changes = _randomChangeSet(random, document.length);
      final ChangeSet inverted = changes.invert(document);
      expect(inverted.apply(changes.apply(document)), document);
      expect(inverted.length, changes.newLength);
    }
  });

  test('positions map through an insertion by side', () {
    expect(e2.mapPosition(5, side: MapSide.before), 5);
    expect(e2.mapPosition(5, side: MapSide.after), 8);
    for (final MapSide side in MapSide.values) {
      expect(e2.mapPosition(0, side: side), 0);
      expect(e2.mapPosition(11, side: side), 14);
      expect(e2.mapPosition(6, side: side), 9);
    }

    final ChangeSet replace = ChangeSet(
      length: 10,
      replacements: const <TextReplacement>[TextReplacement(2, 5, 'xy')],
    );
    for (final MapSide side in MapSide.values) {
      expect(replace.mapPosition(1, side: side), 1);
      expect(replace.mapPosition(2, side: side), 2);
      expect(replace.mapPosition(5, side: side), 4);
      expect(replace.mapPosition(7, side: side), 6);
    }
    expect(replace.mapPosition(3, side: MapSide.before), 2);
    expect(replace.mapPosition(3, side: MapSide.after), 4);

    expect(() => e2.mapPosition(-1, side: MapSide.before), throwsRangeError);
    expect(() => e2.mapPosition(12, side: MapSide.after), throwsRangeError);
    expect(
      () => replace.mapPosition(11, side: MapSide.before),
      throwsRangeError,
    );
  });

  test('composed change sets equal sequential application', () {
    final ChangeSet b = ChangeSet(
      length: 14,
      replacements: const <TextReplacement>[
        TextReplacement(0, 1, 'H'),
        TextReplacement(8, 9, '_'),
      ],
    );
    final ChangeSet composed = e2.compose(b);
    expect(
      composed,
      ChangeSet(
        length: 11,
        replacements: const <TextReplacement>[
          TextReplacement(0, 1, 'H'),
          TextReplacement(5, 6, 'abc_'),
        ],
      ),
    );
    expect(composed.apply('hello world'), 'Helloabc_world');

    final Random random = Random(20260923);
    for (int i = 0; i < 1000; i++) {
      final String document = _randomText(random, 80);
      final ChangeSet first = _randomChangeSet(random, document.length);
      final String middle = first.apply(document);
      final ChangeSet second = _randomChangeSet(random, middle.length);
      final ChangeSet both = first.compose(second);
      expect(both.apply(document), second.apply(middle));
      expect(both.length, first.length);
      expect(both.newLength, second.newLength);
    }

    expect(ChangeSet.empty(11).compose(e2), e2);
    expect(e2.compose(ChangeSet.empty(14)), e2);
  });

  test('overlapping replacements are rejected', () {
    expect(
      () => ChangeSet(
        length: 10,
        replacements: const <TextReplacement>[
          TextReplacement(2, 5, 'a'),
          TextReplacement(4, 6, 'b'),
        ],
      ),
      throwsArgumentError,
    );
    expect(
      () => ChangeSet(
        length: 10,
        replacements: const <TextReplacement>[
          TextReplacement(6, 7, ''),
          TextReplacement(2, 3, ''),
        ],
      ),
      throwsArgumentError,
    );
    expect(
      () => ChangeSet(
        length: 10,
        replacements: const <TextReplacement>[TextReplacement(8, 12, '')],
      ),
      throwsArgumentError,
    );
    expect(
      () => ChangeSet(
        length: 10,
        replacements: const <TextReplacement>[TextReplacement(5, 3, '')],
      ),
      throwsArgumentError,
    );
    expect(
      () => ChangeSet(length: -1, replacements: const <TextReplacement>[]),
      throwsArgumentError,
    );

    expect(
      ChangeSet(
        length: 10,
        replacements: const <TextReplacement>[
          TextReplacement(2, 4, 'a'),
          TextReplacement(4, 6, 'b'),
        ],
      ).replacements,
      const <TextReplacement>[TextReplacement(2, 6, 'ab')],
    );
    expect(
      ChangeSet(
        length: 10,
        replacements: const <TextReplacement>[
          TextReplacement(3, 3, 'a'),
          TextReplacement(3, 3, 'b'),
        ],
      ).replacements,
      const <TextReplacement>[TextReplacement(3, 3, 'ab')],
    );
  });

  test('apply, invert and compose reject a length mismatch', () {
    expect(() => e2.apply('hello'), throwsArgumentError);
    expect(() => e2.invert('hello'), throwsArgumentError);
    expect(() => e2.compose(ChangeSet.empty(11)), throwsArgumentError);
  });

  test('isEmpty and newLength follow the canonical form', () {
    expect(ChangeSet.empty(4).isEmpty, isTrue);
    expect(ChangeSet.empty(4).newLength, 4);
    final ChangeSet noOps = ChangeSet(
      length: 6,
      replacements: const <TextReplacement>[
        TextReplacement(1, 1, ''),
        TextReplacement(4, 4, ''),
      ],
    );
    expect(noOps.isEmpty, isTrue);
    expect(noOps, ChangeSet.empty(6));
    expect(e2.isEmpty, isFalse);
    expect(e2.newLength, 14);
    expect(ChangeSet.single(10, 2, 5, 'xy').newLength, 9);
  });

  test('a no-op between touching replacements is dropped before merging', () {
    expect(
      ChangeSet(
        length: 10,
        replacements: const <TextReplacement>[
          TextReplacement(2, 4, 'a'),
          TextReplacement(4, 4, ''),
          TextReplacement(4, 6, 'b'),
        ],
      ).replacements,
      const <TextReplacement>[TextReplacement(2, 6, 'ab')],
    );
  });

  test('inverting the inverse gives the original set', () {
    final Random random = Random(20260923);
    for (int i = 0; i < 500; i++) {
      final String document = _randomText(random, 80);
      final ChangeSet changes = _randomChangeSet(random, document.length);
      final ChangeSet inverse = changes.invert(document);
      expect(inverse.invert(changes.apply(document)), changes);
    }
  });

  test('single and empty build the expected sets', () {
    expect(
      ChangeSet.single(11, 5, 5, 'abc'),
      ChangeSet(
        length: 11,
        replacements: const <TextReplacement>[TextReplacement(5, 5, 'abc')],
      ),
    );
    expect(ChangeSet.single(11, 5, 5, ''), ChangeSet.empty(11));
    expect(ChangeSet.empty(0).apply(''), '');
    expect(ChangeSet.single(0, 0, 0, 'x').apply(''), 'x');
    expect(ChangeSet.empty(0).mapPosition(0, side: MapSide.after), 0);
    expect(() => ChangeSet.single(3, 2, 4, 'x'), throwsArgumentError);
    expect(
      ChangeSet.single(11, 5, 5, 'abc').hashCode,
      ChangeSet.single(11, 5, 5, 'abc').hashCode,
    );
    expect(
      const TextReplacement(5, 5, 'abc').toString(),
      "TextReplacement(5, 5, 'abc')",
    );
  });

  test('carriage returns and surrogate halves are moved as plain units', () {
    const String document = 'a\r\nb\u{1F44D}c';
    final ChangeSet changes = ChangeSet.single(document.length, 2, 5, '');
    expect(changes.apply(document), 'a\r\udc4dc');
    expect(changes.invert(document).apply(changes.apply(document)), document);
  });

  test('mapped positions are monotonic in position and side', () {
    final Random random = Random(20260923);
    for (int i = 0; i < 500; i++) {
      final int length = random.nextInt(40);
      final ChangeSet changes = _randomChangeSet(random, length);
      for (int p = 0; p <= length; p++) {
        final int before = changes.mapPosition(p, side: MapSide.before);
        final int after = changes.mapPosition(p, side: MapSide.after);
        expect(before, lessThanOrEqualTo(after));
        expect(after, lessThanOrEqualTo(changes.newLength));
        if (p < length) {
          expect(
            before,
            lessThanOrEqualTo(changes.mapPosition(p + 1, side: MapSide.before)),
          );
          expect(
            after,
            lessThanOrEqualTo(changes.mapPosition(p + 1, side: MapSide.after)),
          );
        }
      }
    }
  });

  test('replacements is unmodifiable', () {
    expect(
      () => e2.replacements.add(const TextReplacement(0, 0, 'x')),
      throwsUnsupportedError,
    );
    final List<TextReplacement> source = <TextReplacement>[
      const TextReplacement(1, 2, 'x'),
    ];
    final ChangeSet changes = ChangeSet(length: 4, replacements: source);
    source.add(const TextReplacement(3, 4, 'y'));
    expect(changes.replacements, const <TextReplacement>[
      TextReplacement(1, 2, 'x'),
    ]);
  });
}
