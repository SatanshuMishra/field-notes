import 'package:field_notes/domain/notes/markdown/block_parser.dart';
import 'package:field_notes/domain/notes/markdown/photo_line.dart';
import 'package:field_notes/domain/notes/markdown/syntax_tree.dart';
import 'package:flutter_test/flutter_test.dart';

const MdBlockParser _parser = MdBlockParser();

const String _p = '![p](photo/abc123abc123)';

String _range(MdRange range) => '${range.start}-${range.end}';

String _describe(MdBlock block) =>
    '${block.kind.name} ${_range(block.sourceRange)} '
    'c${_range(block.contentRange)} '
    'm[${block.markerRanges.map(_range).join(' ')}]';

List<String> _render(List<MdBlock> blocks, [String indent = '']) => <String>[
  for (final MdBlock block in blocks) ...<String>[
    '$indent${_describe(block)}',
    ..._render(block.blocks, '$indent  '),
  ],
];

List<String> _parse(String source) => _render(_parser.parse(source));

List<String> _topLevel(String source) => <String>[
  for (final MdBlock block in _parser.parse(source))
    '${block.kind.name} ${_range(block.sourceRange)}',
];

Iterable<MdBlock> _allBlocks(List<MdBlock> blocks) sync* {
  for (final MdBlock block in blocks) {
    yield block;
    yield* _allBlocks(block.blocks);
  }
}

MdPhotoLineData _photo(String source) =>
    _parser.parse(source).single.photoLine!;

void main() {
  test(
    'a photo line interrupts a paragraph and closes a list, quote or table',
    () {
      expect(_topLevel('A\n$_p'), <String>['paragraph 0-1', 'photoLine 2-26']);
      expect(_topLevel('- a\n$_p\n- b'), <String>[
        'bulletList 0-3',
        'photoLine 4-28',
        'bulletList 29-32',
      ]);
      expect(_topLevel('> q\n$_p'), <String>[
        'blockQuote 0-3',
        'photoLine 4-28',
      ]);
      expect(_topLevel('A\n$_p\nB'), <String>[
        'paragraph 0-1',
        'photoLine 2-26',
        'paragraph 27-28',
      ]);
      expect(_topLevel('| a |\n| - |\n| b |\n$_p'), <String>[
        'table 0-17',
        'photoLine 18-42',
      ]);
      final MdBlock table = _parser.parse('| a |\n| - |\n| b |\n$_p').first;
      expect(table.blocks.map((MdBlock row) => row.kind), <MdBlockKind>[
        MdBlockKind.tableRow,
        MdBlockKind.tableRow,
      ]);
      expect(table.blocks.last.sourceRange, const MdRange(12, 17));
    },
  );

  test('a line continued by a container is never a photo line', () {
    expect(_parse('- a\n  $_p'), <String>[
      'bulletList 0-30 c0-30 m[]',
      '  listItem 0-30 c2-30 m[0-2 4-6]',
      '    paragraph 2-30 c2-30 m[]',
    ]);
    expect(_parse('> $_p'), <String>[
      'blockQuote 0-26 c2-26 m[0-2]',
      '  paragraph 2-26 c2-26 m[]',
    ]);
    expect(_parse('> a\n> $_p'), <String>[
      'blockQuote 0-30 c2-30 m[0-2 4-6]',
      '  paragraph 2-30 c2-30 m[]',
    ]);
    expect(_parse('```\n$_p\n```'), <String>[
      'fencedCode 0-32 c4-28 m[0-3 29-32]',
    ]);
    expect(_parse('- a\n\n  $_p'), <String>[
      'bulletList 0-31 c0-31 m[]',
      '  listItem 0-31 c2-31 m[0-2 5-7]',
      '    paragraph 2-3 c2-3 m[]',
      '    paragraph 7-31 c7-31 m[]',
    ]);
    for (final String source in <String>[
      '- a\n  $_p',
      '> $_p',
      '> a\n> $_p',
      '```\n$_p\n```',
      '- a\n\n  $_p',
    ]) {
      expect(
        _allBlocks(
          _parser.parse(source),
        ).where((MdBlock block) => block.kind == MdBlockKind.photoLine),
        isEmpty,
        reason: source,
      );
    }
    expect(_parse(_p), <String>['photoLine 0-24 c2-3 m[0-2 3-24]']);
  });

  test(
    'any hex reference parses and only lowercase twelve to sixty four digits resolve',
    () {
      final String sixtyFour = 'a1' * 32;
      final String sixtyFive = '${'a1' * 32}b';
      for (final (String reference, bool resolves) in <(String, bool)>[
        ('abc123abc123', true),
        (sixtyFour, true),
        ('abc123abc12', false),
        (sixtyFive, false),
        ('ABC123ABC123', false),
        ('Abc123abc123', false),
        ('ab', false),
      ]) {
        final MdPhotoLineData data = _photo('![](photo/$reference)');
        expect(data.reference, reference);
        expect(data.canResolve, resolves, reason: reference);
      }
      expect(_topLevel('![](photo/abc123abc12g)'), <String>['paragraph 0-23']);
      expect(_topLevel('![](photo/)'), <String>['paragraph 0-11']);
    },
  );

  test(
    'placement words are case insensitive, order free and accept center',
    () {
      for (final (String title, MdPhotoSide side, MdPhotoSize size)
          in <(String, MdPhotoSide, MdPhotoSize)>[
            ('Left SMALL', MdPhotoSide.left, MdPhotoSize.small),
            ('large centre', MdPhotoSide.centre, MdPhotoSize.large),
            ('center full', MdPhotoSide.centre, MdPhotoSize.full),
            ('RIGHT', MdPhotoSide.right, MdPhotoSize.medium),
            ('small', MdPhotoSide.right, MdPhotoSize.small),
            (' left\tlarge ', MdPhotoSide.left, MdPhotoSize.large),
          ]) {
        expect(
          MdPhotoPlacement.parse(title),
          MdPhotoPlacement(side: side, size: size),
          reason: title,
        );
        expect(MdPhotoPlacement.parse(title).isValid, isTrue);
      }
      expect(
        _photo('![](photo/abc123abc123 "Center Large")').placement,
        const MdPhotoPlacement(
          side: MdPhotoSide.centre,
          size: MdPhotoSize.large,
        ),
      );
    },
  );

  test('an empty title is right medium and a repeated word is invalid', () {
    for (final String source in <String>[
      '![](photo/abc123abc123)',
      '![](photo/abc123abc123 "")',
      '![](photo/abc123abc123 "   ")',
    ]) {
      final MdPhotoPlacement placement = _photo(source).placement;
      expect(placement, const MdPhotoPlacement(), reason: source);
      expect(placement.isValid, isTrue);
      expect(placement.side, MdPhotoSide.right);
      expect(placement.size, MdPhotoSize.medium);
    }
    for (final String title in <String>[
      'left left',
      'left right',
      'small large',
      'centre center',
      'right huge',
      'sideways',
      'right medium tilt',
    ]) {
      final MdPhotoPlacement placement = MdPhotoPlacement.parse(title);
      expect(placement, const MdPhotoPlacement.invalid(), reason: title);
      expect(placement.side, MdPhotoSide.centre);
      expect(placement.size, MdPhotoSize.medium);
      expect(placement.isValid, isFalse);
      expect(placement.format(), 'centre medium');
    }
    final MdPhotoPlacement sided = MdPhotoPlacement.parse(
      'right huge',
    ).copyWith(side: MdPhotoSide.left);
    expect(sided.isValid, isTrue);
    expect(sided.format(), 'left medium');
    expect(
      MdPhotoPlacement.parse(
        'right huge',
      ).copyWith(size: MdPhotoSize.large).format(),
      'centre large',
    );
    expect(
      const MdPhotoPlacement.invalid().toString(),
      'MdPhotoPlacement(centre medium, invalid)',
    );
    expect(
      const MdPhotoPlacement(side: MdPhotoSide.left).toString(),
      'MdPhotoPlacement(left medium)',
    );
  });

  test(
    'sizes carry the one third, one half, two thirds and full fractions',
    () {
      expect(MdPhotoSize.values, <MdPhotoSize>[
        MdPhotoSize.small,
        MdPhotoSize.medium,
        MdPhotoSize.large,
        MdPhotoSize.full,
      ]);
      expect(
        MdPhotoSize.values.map((MdPhotoSize size) => size.fraction),
        <double>[1 / 3, 1 / 2, 2 / 3, 1.0],
      );
      expect(MdPhotoSize.values.map((MdPhotoSize size) => size.label), <String>[
        'Small',
        'Medium',
        'Large',
        'Full',
      ]);
      expect(
        MdPhotoSize.values.map((MdPhotoSize size) => size.shortLabel),
        <String>['S', 'M', 'L', 'Full'],
      );
      expect(MdPhotoSide.values, <MdPhotoSide>[
        MdPhotoSide.left,
        MdPhotoSide.centre,
        MdPhotoSide.right,
      ]);
      expect(MdPhotoSide.values.map((MdPhotoSide side) => side.label), <String>[
        'Left',
        'Centre',
        'Right',
      ]);
    },
  );

  test(
    'the canonical line writes the side word centre and a sanitised caption',
    () {
      expect(
        canonicalPhotoLine(
          'abc123abc123',
          '  Low ]tide\r\nat dusk ',
          const MdPhotoPlacement(
            side: MdPhotoSide.centre,
            size: MdPhotoSize.large,
          ),
        ),
        '![Low tide  at dusk](photo/abc123abc123 "centre large")',
      );
      expect(
        canonicalPhotoLine('ABC', '', MdPhotoPlacement.parse('center small')),
        '![](photo/ABC "centre small")',
      );
      expect(
        canonicalPhotoLine('abc123abc123', '', const MdPhotoPlacement()),
        '![](photo/abc123abc123 "right medium")',
      );
      expect(sanitizePhotoCaption('a]b\nc\rd'), 'ab c d');
      expect(sanitizePhotoCaption('x\r\ny'), 'x  y');
    },
  );

  test('photo line ranges cover the caption, reference and title', () {
    const String padded = '  $_p  ';
    final MdPhotoLineData spaced = _photo(padded);
    expect(spaced.captionRange, const MdRange(4, 5));
    expect(spaced.referenceRange, const MdRange(13, 25));
    expect(spaced.title, isNull);
    expect(spaced.titleRange, isNull);
    expect(_parse(padded), <String>['photoLine 0-28 c4-5 m[0-4 5-28]']);
    final MdPhotoLineData titled = _photo(
      '![Low tide](photo/abc123abc123 "left medium")',
    );
    expect(titled.caption, 'Low tide');
    expect(titled.captionRange, const MdRange(2, 10));
    expect(titled.referenceRange, const MdRange(18, 30));
    expect(titled.title, 'left medium');
    expect(titled.titleRange, const MdRange(32, 43));
    expect(titled.placement, const MdPhotoPlacement(side: MdPhotoSide.left));
    final MdPhotoLineData bracket = _photo('![a [b](photo/abc123abc123 "")');
    expect(bracket.caption, 'a [b');
    expect(bracket.captionRange, const MdRange(2, 6));
    expect(bracket.titleRange, const MdRange(28, 28));
    expect(bracket.placement, const MdPhotoPlacement());
  });

  test('near misses are not photo lines', () {
    for (final String source in <String>[
      '$_p x',
      "![p](photo/abc123abc123 'left')",
      '![p](photo/abc123abc123"left")',
      '![p](photo/abc123abc123 )',
    ]) {
      expect(MdPhotoLine.match(source, 0, source.length), isNull);
      expect(_parser.parse(source).single.kind, MdBlockKind.paragraph);
    }
  });

  test('photo lines stand as their own top-level blocks', () {
    expect(_topLevel('A\n    $_p'), <String>[
      'paragraph 0-1',
      'photoLine 2-30',
    ]);
    expect(_topLevel('$_p\n$_p'), <String>[
      'photoLine 0-24',
      'photoLine 25-49',
    ]);
    expect(_topLevel('- a\n\n $_p'), <String>[
      'bulletList 0-3',
      'photoLine 5-30',
    ]);
  });

  test('the block and match views of a photo line agree', () {
    const String source =
        'A\n$_p\n- a\n\n  ![x](photo/ABCDEF "left")\n'
        '![c](photo/abc123abc123 "centre full")';
    final List<MdBlock> blocks = _parser.parse(source);
    int photos = 0;
    for (final MdBlock block in _allBlocks(blocks)) {
      final MdPhotoLineData? data = block.photoLine;
      if (block.kind != MdBlockKind.photoLine) {
        expect(data, isNull);
        continue;
      }
      photos++;
      expect(
        data,
        MdPhotoLine.match(
          source,
          block.sourceRange.start,
          block.sourceRange.end,
        )!.data,
      );
      expect(MdPhotoLine.ofBlock(block, source), MdPhotoLine(data!));
    }
    expect(photos, 2);
    final MdBlock paragraph = blocks.first;
    expect(paragraph.photoLine, isNull);
    expect(() => MdPhotoLine.ofBlock(paragraph, source), throwsArgumentError);
    final MdPhotoLine matched = MdPhotoLine.match(
      '![p](photo/abc123abc123 "left small")',
      0,
      37,
    )!;
    expect(matched.reference, 'abc123abc123');
    expect(
      matched.placement,
      const MdPhotoPlacement(side: MdPhotoSide.left, size: MdPhotoSize.small),
    );
    expect(matched.data.placement, matched.placement);
  });

  test('the fixture form of the canonical writer', () {
    expect(
      canonicalPhotoLine(
        'a1b2c3d4e5f6',
        '',
        MdPhotoPlacement(side: MdPhotoSide.left, size: MdPhotoSize.small),
      ),
      '![](photo/a1b2c3d4e5f6 "left small")',
    );
  });

  test('the canonical line round trips through match', () {
    for (final MdPhotoSide side in MdPhotoSide.values) {
      for (final MdPhotoSize size in MdPhotoSize.values) {
        for (final String caption in <String>[
          '',
          ' Harbour ',
          'a]b\r\nc',
          'x [y',
        ]) {
          final MdPhotoPlacement placement = MdPhotoPlacement(
            side: side,
            size: size,
          );
          final String line = canonicalPhotoLine(
            'abc123abc123',
            caption,
            placement,
          );
          final MdPhotoLine matched = MdPhotoLine.match(line, 0, line.length)!;
          expect(matched.reference, 'abc123abc123');
          expect(matched.caption, sanitizePhotoCaption(caption).trim());
          expect(matched.placement, placement);
        }
      }
    }
  });
}
