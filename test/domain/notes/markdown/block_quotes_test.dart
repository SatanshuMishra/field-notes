import 'package:field_notes/domain/notes/markdown/block_parser.dart';
import 'package:field_notes/domain/notes/markdown/blocks/block_quotes.dart';
import 'package:field_notes/domain/notes/markdown/source_lines.dart';
import 'package:field_notes/domain/notes/markdown/syntax_tree.dart';
import 'package:flutter_test/flutter_test.dart';

const MdBlockParser _parser = MdBlockParser();

String _range(MdRange range) => '${range.start}-${range.end}';

String _data(MdBlockData? data) => switch (data) {
  MdHeadingData() => ' level ${data.level}',
  MdFenceData() => ' ${data.isClosed ? 'closed' : 'open'}',
  _ => '',
};

String _describe(MdBlock block) =>
    '${block.kind.name} ${_range(block.sourceRange)} '
    'c${_range(block.contentRange)} '
    'm[${block.markerRanges.map(_range).join(' ')}]'
    '${_data(block.data)}';

List<String> _render(List<MdBlock> blocks, [String indent = '']) => <String>[
  for (final MdBlock block in blocks) ...<String>[
    '$indent${_describe(block)}',
    ..._render(block.blocks, '$indent  '),
  ],
];

List<String> _parse(String source) => _render(_parser.parse(source));

void main() {
  test('nested quotes keep each marker and its optional space', () {
    expect(_parse('> > > foo\nbar'), <String>[
      'blockQuote 0-13 c2-13 m[0-2]',
      '  blockQuote 2-13 c4-13 m[2-4]',
      '    blockQuote 4-13 c6-13 m[4-6]',
      '      paragraph 6-13 c6-13 m[]',
    ]);
    expect(_parse('>>> foo\n> bar\n>>baz'), <String>[
      'blockQuote 0-19 c1-19 m[0-1 8-10 14-15]',
      '  blockQuote 1-19 c2-19 m[1-2 15-16]',
      '    blockQuote 2-19 c4-19 m[2-4]',
      '      paragraph 4-19 c4-19 m[]',
    ]);
    expect(_parse('   > a'), <String>[
      'blockQuote 0-6 c5-6 m[0-5]',
      '  paragraph 5-6 c5-6 m[]',
    ]);
    expect(_parse('>\tfoo'), <String>[
      'blockQuote 0-5 c2-5 m[0-2]',
      '  paragraph 2-5 c2-5 m[]',
    ]);
  });

  test('a lazy line joins the open paragraph in a quote', () {
    expect(_parse('> bar\nbaz'), <String>[
      'blockQuote 0-9 c2-9 m[0-2]',
      '  paragraph 2-9 c2-9 m[]',
    ]);
    expect(_parse('> "Quote"\n— Author'), <String>[
      'blockQuote 0-18 c2-18 m[0-2]',
      '  paragraph 2-18 c2-18 m[]',
    ]);
    expect(_parse('> bar\n\nbaz'), <String>[
      'blockQuote 0-5 c2-5 m[0-2]',
      '  paragraph 2-5 c2-5 m[]',
      'paragraph 7-10 c7-10 m[]',
    ]);
    expect(_parse('> foo\n---'), <String>[
      'blockQuote 0-5 c2-5 m[0-2]',
      '  paragraph 2-5 c2-5 m[]',
      'thematicBreak 6-9 c9-9 m[6-9]',
    ]);
    expect(_parse('> ```\nfoo'), <String>[
      'blockQuote 0-5 c2-5 m[0-2]',
      '  fencedCode 2-5 c5-5 m[2-5] open',
      'paragraph 6-9 c6-9 m[]',
    ]);
  });

  test('a heading or list inside a quote is parsed as that block', () {
    expect(_parse('> # Foo\n> bar\n> baz'), <String>[
      'blockQuote 0-19 c2-19 m[0-2 8-10 14-16]',
      '  heading 2-7 c4-7 m[2-4] level 1',
      '  paragraph 10-19 c10-19 m[]',
    ]);
    expect(_parse('># Foo\n>bar'), <String>[
      'blockQuote 0-11 c1-11 m[0-1 7-8]',
      '  heading 1-6 c3-6 m[1-3] level 1',
      '  paragraph 8-11 c8-11 m[]',
    ]);
    expect(_parse('> ```\n> a\n> ```'), <String>[
      'blockQuote 0-15 c2-15 m[0-2 6-8 10-12]',
      '  fencedCode 2-15 c8-9 m[2-5 12-15] closed',
    ]);
    final MdBlock quote = _parser.parse('> - x').single;
    expect(quote.kind, MdBlockKind.blockQuote);
    expect(quote.sourceRange, const MdRange(0, 5));
    expect(quote.markerRanges, <MdRange>[const MdRange(0, 2)]);
    expect(quote.blocks.single.sourceRange, const MdRange(2, 5));
  });

  test('a blank quote line ends the paragraph and makes no node', () {
    expect(_parse('> a\n>\n> b'), <String>[
      'blockQuote 0-9 c2-9 m[0-2 4-5 6-8]',
      '  paragraph 2-3 c2-3 m[]',
      '  paragraph 8-9 c8-9 m[]',
    ]);
    expect(_parse('> a\n>   \n> b'), <String>[
      'blockQuote 0-12 c2-12 m[0-2 4-6 6-8 9-11]',
      '  paragraph 2-3 c2-3 m[]',
      '  paragraph 11-12 c11-12 m[]',
    ]);
    expect(_parse('>'), <String>['blockQuote 0-1 c1-1 m[0-1]']);
  });

  test('a blank quote line inside a fence is code', () {
    expect(_parse('> ```\n>\n> a\n> ```'), <String>[
      'blockQuote 0-17 c2-17 m[0-2 6-7 8-10 12-14]',
      '  fencedCode 2-17 c7-11 m[2-5 14-17] closed',
    ]);
    expect(_parse('> ```\n>   \n> ```'), <String>[
      'blockQuote 0-16 c2-16 m[0-2 6-8 11-13]',
      '  fencedCode 2-16 c8-10 m[2-5 13-16] closed',
    ]);
  });

  test('the quote rows of the markup table parse as that block', () {
    expect(_parse('> > x'), <String>[
      'blockQuote 0-5 c2-5 m[0-2]',
      '  blockQuote 2-5 c4-5 m[2-4]',
      '    paragraph 4-5 c4-5 m[]',
    ]);
    expect(_parse('> # x'), <String>[
      'blockQuote 0-5 c2-5 m[0-2]',
      '  heading 2-5 c4-5 m[2-4] level 1',
    ]);
    expect(_parse('foo\n> bar'), <String>[
      'paragraph 0-3 c0-3 m[]',
      'blockQuote 4-9 c6-9 m[4-6]',
      '  paragraph 6-9 c6-9 m[]',
    ]);
  });

  test('indentation inside a quote is paragraph text', () {
    expect(_parse('>     foo\n    bar'), <String>[
      'blockQuote 0-17 c2-17 m[0-2]',
      '  paragraph 2-17 c6-17 m[2-6 10-14]',
    ]);
    expect(_parse('    > a'), <String>['paragraph 0-7 c4-7 m[0-4]']);
  });

  test('a fence ends with its quote', () {
    expect(_parse('> a\n> ```\n> b\nc'), <String>[
      'blockQuote 0-13 c2-13 m[0-2 4-6 10-12]',
      '  paragraph 2-3 c2-3 m[]',
      '  fencedCode 6-13 c12-13 m[6-9] open',
      'paragraph 14-15 c14-15 m[]',
    ]);
  });

  test('a crlf quote keeps one marker per line', () {
    expect(_parse('> a\r\n> b'), <String>[
      'blockQuote 0-8 c2-8 m[0-2 5-7]',
      '  paragraph 2-8 c2-8 m[]',
    ]);
  });

  test('the quote marker reader needs a greater-than sign', () {
    final MdSourceLines lines = MdSourceLines.split('a\n   >\tb\n    > c');
    expect(MdBlockQuotes.consumeMarker(MdLineCursor.atLine(lines, 0)), isNull);
    final MdLineCursor after = MdBlockQuotes.consumeMarker(
      MdLineCursor.atLine(lines, 1),
    )!;
    expect(after.offset, 7);
    expect(after.virtualColumns, 3);
    expect(MdBlockQuotes.consumeMarker(MdLineCursor.atLine(lines, 2)), isNull);
  });

  test('inline segments of a lazy paragraph skip every quote marker', () {
    const String source = '>>> foo\n> bar\n>>baz';
    final MdBlock outer = _parser.parse(source).single;
    final MdBlock middle = outer.blocks.single;
    final MdBlock inner = middle.blocks.single;
    expect(
      MdBlockParser.inlineSegments(
        MdSourceLines.split(source),
        inner.blocks.single,
        <MdBlock>[outer, middle, inner],
      ),
      <MdRange>[
        const MdRange(4, 7),
        const MdRange(10, 13),
        const MdRange(16, 19),
      ],
    );
  });
}
