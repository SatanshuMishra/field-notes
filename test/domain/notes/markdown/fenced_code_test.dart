import 'package:field_notes/domain/notes/markdown/block_parser.dart';
import 'package:field_notes/domain/notes/markdown/blocks/fenced_code.dart';
import 'package:field_notes/domain/notes/markdown/source_lines.dart';
import 'package:field_notes/domain/notes/markdown/syntax_tree.dart';
import 'package:flutter_test/flutter_test.dart';

const MdBlockParser _parser = MdBlockParser();

String _range(MdRange range) => '${range.start}-${range.end}';

String _data(MdBlockData? data) => switch (data) {
  MdFenceData() =>
    ' fence(${data.fence}|${data.info}|'
        '${data.isClosed ? 'closed' : 'open'})',
  MdHeadingData() => ' level ${data.level}',
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

MdFence? _open(String source) =>
    MdFence.open(MdLineCursor.atLine(MdSourceLines.split(source), 0));

void main() {
  test('backtick and tilde fences open code blocks with an info string', () {
    const String dart = '```dart\nlet x\n```';
    expect(_parse(dart), <String>[
      'fencedCode 0-17 c8-13 m[0-7 14-17] fence(```|dart|closed)',
    ]);
    final MdBlock block = _parser.parse(dart).single;
    expect(
      block.data,
      const MdFenceData(fence: '```', info: 'dart', isClosed: true),
    );
    expect(
      MdFence.ofBlock(block, MdSourceLines.split(dart)),
      const MdFence(
        character: 0x60,
        length: 3,
        indent: 0,
        infoRange: MdRange(3, 7),
      ),
    );
    expect(_parse('~~~ js title\nx\n~~~'), <String>[
      'fencedCode 0-18 c13-14 m[0-12 15-18] fence(~~~|js title|closed)',
    ]);
    expect(
      _parser.parse('~~~ a`b\nx\n~~~').single.data,
      const MdFenceData(fence: '~~~', info: 'a`b', isClosed: true),
    );
    expect(_parse('``` a`b'), <String>['paragraph 0-7 c0-7 m[]']);
    expect(_parse('``\nfoo\n``'), <String>['paragraph 0-9 c0-9 m[]']);
    expect(_parse('````\naaa\n```\n``````'), <String>[
      'fencedCode 0-19 c5-12 m[0-4 13-19] fence(````||closed)',
    ]);
    expect(_parse('~~~\naaa\n```\n~~~'), <String>[
      'fencedCode 0-15 c4-11 m[0-3 12-15] fence(~~~||closed)',
    ]);
    expect(_parse('```\n```'), <String>[
      'fencedCode 0-7 c3-3 m[0-3 4-7] fence(```||closed)',
    ]);
  });

  test('an unclosed fence runs to the end of the note', () {
    expect(_parse('```\nfoo\n\nbar'), <String>[
      'fencedCode 0-12 c4-12 m[0-3] fence(```||open)',
    ]);
    expect(_parse('`````\n\n```\naaa'), <String>[
      'fencedCode 0-14 c6-14 m[0-5] fence(`````||open)',
    ]);
    expect(_parse('foo\n```\nbar'), <String>[
      'paragraph 0-3 c0-3 m[]',
      'fencedCode 4-11 c8-11 m[4-7] fence(```||open)',
    ]);
    expect(_parse('```\n'), <String>[
      'fencedCode 0-4 c4-4 m[0-3] fence(```||open)',
    ]);
    expect(_parse('```\n# not a heading\n- x'), <String>[
      'fencedCode 0-23 c4-23 m[0-3] fence(```||open)',
    ]);
    expect(_parse('```\naaa\n    ```'), <String>[
      'fencedCode 0-15 c4-15 m[0-3] fence(```||open)',
    ]);
  });

  test('fence indentation stripped from code lines is recorded as markers', () {
    expect(_parse('  ```\naaa\n  aaa\n    aaa\n  ```'), <String>[
      'fencedCode 0-29 c6-23 m[0-5 10-12 16-18 24-29] fence(```||closed)',
    ]);
    expect(_parse('   ```\n   aaa\n    aaa\n  aaa\n   ```'), <String>[
      'fencedCode 0-34 c10-27 m[0-6 7-10 14-17 22-24 28-34] '
          'fence(```||closed)',
    ]);
  });

  test('a fence interrupts a paragraph and a closed fence ends it', () {
    expect(_parse('foo\n```\nbar\n```\nbaz'), <String>[
      'paragraph 0-3 c0-3 m[]',
      'fencedCode 4-15 c8-11 m[4-7 12-15] fence(```||closed)',
      'paragraph 16-19 c16-19 m[]',
    ]);
    expect(_parse('```\nx\n```  '), <String>[
      'fencedCode 0-11 c4-5 m[0-3 6-11] fence(```||closed)',
    ]);
    expect(_parse('```\na\n```\n\nb'), <String>[
      'fencedCode 0-9 c4-5 m[0-3 6-9] fence(```||closed)',
      'paragraph 11-12 c11-12 m[]',
    ]);
    expect(_parse('```\n\n  \n```'), <String>[
      'fencedCode 0-11 c4-7 m[0-3 8-11] fence(```||closed)',
    ]);
    expect(_parse('```\r\nx\r\n```'), <String>[
      'fencedCode 0-11 c5-6 m[0-3 8-11] fence(```||closed)',
    ]);
    expect(_parse('```\n``` aaa\n```'), <String>[
      'fencedCode 0-15 c4-11 m[0-3 12-15] fence(```||closed)',
    ]);
  });

  test('fence recognition rejects short runs, indentation and backticks', () {
    expect(_open('``'), isNull);
    expect(_open('    ```'), isNull);
    expect(_open('``` a`b'), isNull);
    expect(
      _open('~~~ a`b'),
      const MdFence(
        character: 0x7E,
        length: 3,
        indent: 0,
        infoRange: MdRange(4, 7),
      ),
    );
    expect(_open('```')!.infoRange, const MdRange(3, 3));
    final MdFence fence = _open('````')!;
    final MdSourceLines closers = MdSourceLines.split('```\n``````\n  ````  ');
    expect(fence.closes(MdLineCursor.atLine(closers, 0)), isFalse);
    expect(fence.closes(MdLineCursor.atLine(closers, 1)), isTrue);
    expect(fence.closes(MdLineCursor.atLine(closers, 2)), isTrue);
  });

  test('the info string resolves backslash escapes and keeps entities', () {
    const String source =
        r'``` foo\+bar'
        '\na\n```';
    expect(source.length, 18);
    final MdFence fence = _open(source)!;
    expect(fence.infoRange, const MdRange(4, 12));
    expect(fence.info(source), 'foo+bar');
    expect((_parser.parse(source).single.data! as MdFenceData).info, 'foo+bar');
    const String entity = '``` a&amp;b\\q\n```';
    expect(_open(entity)!.info(entity), r'a&amp;b\q');
  });

  test('a partly removed tab belongs wholly to the marker', () {
    expect(_parse('  ```\n\tx\n  ```'), <String>[
      'fencedCode 0-14 c7-8 m[0-5 6-7 9-14] fence(```||closed)',
    ]);
  });

  test('a photo line inside a code block is code', () {
    expect(_parse('```\n![p](photo/abc123abc123)\n```'), <String>[
      'fencedCode 0-32 c4-28 m[0-3 29-32] fence(```||closed)',
    ]);
  });
}
