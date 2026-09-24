import 'dart:math';

import 'package:field_notes/domain/notes/markdown/block_parser.dart';
import 'package:field_notes/domain/notes/markdown/source_lines.dart';
import 'package:field_notes/domain/notes/markdown/syntax_tree.dart';
import 'package:flutter_test/flutter_test.dart';

import '../note_fuzz_corpus.dart';

const MdBlockParser _parser = MdBlockParser();

String _range(MdRange range) => '${range.start}-${range.end}';

String _describe(MdBlock block) {
  final MdBlockData? data = block.data;
  final String level = data is MdHeadingData ? '${data.level}' : '';
  return '${block.kind.name}$level ${_range(block.sourceRange)} '
      'c${_range(block.contentRange)} '
      'm[${block.markerRanges.map(_range).join(' ')}]';
}

List<String> _render(List<MdBlock> blocks, [String indent = '']) => <String>[
  for (final MdBlock block in blocks) ...<String>[
    '$indent${_describe(block)}',
    ..._render(block.blocks, '$indent  '),
  ],
];

List<String> _parse(String source) => _render(_parser.parse(source));

List<(int, int, int)> _split(String source) => <(int, int, int)>[
  for (final MdSourceLine line in MdSourceLines.split(source).lines)
    (line.start, line.end, line.breakEnd),
];

bool _isBlank(String source, MdSourceLine line) {
  for (int at = line.start; at < line.end; at++) {
    final int unit = source.codeUnitAt(at);
    if (unit != 0x20 && unit != 0x09) {
      return false;
    }
  }
  return true;
}

bool _inside(MdRange inner, MdRange outer) =>
    inner.start >= outer.start && inner.end <= outer.end;

void _checkNode(
  String source,
  MdSourceLines lines,
  MdBlock block,
  List<MdBlock> ancestors,
) {
  final String where = '${block.kind.name} ${block.sourceRange} in $source';
  expect(block.kind, isNot(MdBlockKind.blankLine), reason: where);
  expect(_inside(block.contentRange, block.sourceRange), isTrue, reason: where);
  for (int i = 0; i < block.markerRanges.length; i++) {
    final MdRange marker = block.markerRanges[i];
    expect(marker.isEmpty, isFalse, reason: where);
    expect(_inside(marker, block.sourceRange), isTrue, reason: where);
    if (i > 0) {
      expect(
        block.markerRanges[i - 1].end <= marker.start,
        isTrue,
        reason: where,
      );
    }
  }
  for (final MdBlock child in block.blocks) {
    expect(
      _inside(child.sourceRange, block.sourceRange),
      isTrue,
      reason: where,
    );
  }
  if (block.kind == MdBlockKind.heading ||
      block.kind == MdBlockKind.paragraph) {
    _checkSegments(source, lines, block, ancestors, where);
  }
  for (final MdBlock child in block.blocks) {
    _checkNode(source, lines, child, <MdBlock>[...ancestors, block]);
  }
}

void _checkSegments(
  String source,
  MdSourceLines lines,
  MdBlock leaf,
  List<MdBlock> ancestors,
  String where,
) {
  final List<MdRange> segments = MdBlockParser.inlineSegments(
    lines,
    leaf,
    ancestors,
  );
  final MdRange content = leaf.contentRange;
  for (int i = 0; i < segments.length; i++) {
    expect(segments[i].isEmpty, isFalse, reason: where);
    expect(_inside(segments[i], content), isTrue, reason: where);
    if (i > 0) {
      expect(segments[i - 1].end <= segments[i].start, isTrue, reason: where);
    }
  }
  final List<MdRange> markers = <MdRange>[
    for (final MdBlock node in <MdBlock>[...ancestors, leaf])
      ...node.markerRanges,
  ];
  for (int at = content.start; at < content.end; at++) {
    final MdSourceLine line = lines.lines[lines.lineIndexAt(at)];
    final bool inBreak = at >= line.end;
    final bool covered =
        inBreak ||
        segments.any((MdRange s) => s.contains(at)) ||
        markers.any((MdRange m) => m.contains(at));
    expect(covered, isTrue, reason: '$where at $at');
  }
}

void _checkInvariants(String source) {
  final List<MdBlock> blocks = _parser.parse(source);
  final MdSourceLines lines = MdSourceLines.split(source);
  for (int i = 0; i < blocks.length; i++) {
    final MdRange range = blocks[i].sourceRange;
    expect(range.end <= source.length, isTrue, reason: source);
    expect(
      lines.lines[lines.lineIndexAt(range.start)].start,
      range.start,
      reason: source,
    );
    if (i > 0) {
      expect(blocks[i - 1].sourceRange.end < range.start, isTrue);
    }
  }
  for (final MdSourceLine line in lines.lines) {
    final int holders = blocks
        .where(
          (MdBlock block) =>
              line.start >= block.sourceRange.start &&
              line.start <= block.sourceRange.end,
        )
        .length;
    expect(holders <= 1, isTrue, reason: '$source line ${line.index}');
    if (holders == 0) {
      expect(
        _isBlank(source, line),
        isTrue,
        reason: '$source line ${line.index}',
      );
    }
  }
  for (final MdBlock block in blocks) {
    _checkNode(source, lines, block, const <MdBlock>[]);
  }
}

List<String> _generatedSources() {
  const List<String> pieces = <String>[
    '#',
    ' ',
    '\t',
    '-',
    '*',
    '_',
    '=',
    'a',
    '\n',
    '\r\n',
    '\r',
  ];
  final Random random = Random(20260923);
  return List<String>.generate(2000, (_) {
    final int count = random.nextInt(41);
    return List<String>.generate(
      count,
      (_) => pieces[random.nextInt(pieces.length)],
    ).join();
  });
}

void main() {
  test('atx headings of levels one to six keep their marker ranges', () {
    expect(_parse('# a\n## b\n### c\n#### d\n##### e\n###### f'), <String>[
      'heading1 0-3 c2-3 m[0-2]',
      'heading2 4-8 c7-8 m[4-7]',
      'heading3 9-14 c13-14 m[9-13]',
      'heading4 15-21 c20-21 m[15-20]',
      'heading5 22-29 c28-29 m[22-28]',
      'heading6 30-38 c37-38 m[30-37]',
    ]);
    expect(_parse('   ### foo ###   '), <String>[
      'heading3 0-17 c7-10 m[0-7 10-17]',
    ]);
    expect(_parse('## '), <String>['heading2 0-3 c3-3 m[0-3]']);
    expect(_parse('#'), <String>['heading1 0-1 c1-1 m[0-1]']);
    expect(_parse('### ###'), <String>['heading3 0-7 c4-4 m[0-4 4-7]']);
    expect(_parse('# foo#'), <String>['heading1 0-6 c2-6 m[0-2]']);
    expect(_parse('### foo ### b'), <String>['heading3 0-13 c4-13 m[0-4]']);
    expect(_parse('#\tFoo'), <String>['heading1 0-5 c2-5 m[0-2]']);
    expect(_parse('####### g'), <String>['paragraph 0-9 c0-9 m[]']);
  });

  test(
    'setext underlines stay paragraph text and a dash line is a divider',
    () {
      expect(_parse('Foo\n==='), <String>['paragraph 0-7 c0-7 m[]']);
      expect(_parse('Foo\n---'), <String>[
        'paragraph 0-3 c0-3 m[]',
        'thematicBreak 4-7 c7-7 m[4-7]',
      ]);
      expect(_parse('Foo\n   ----      '), <String>[
        'paragraph 0-3 c0-3 m[]',
        'thematicBreak 4-17 c17-17 m[4-17]',
      ]);
      expect(_parse('Foo\n--'), <String>['paragraph 0-6 c0-6 m[]']);
      expect(_parse('Foo\n    ---'), <String>['paragraph 0-11 c0-11 m[4-8]']);
      expect(_parse('==='), <String>['paragraph 0-3 c0-3 m[]']);
      expect(_parse('***'), <String>['thematicBreak 0-3 c3-3 m[0-3]']);
      expect(_parse('___'), <String>['thematicBreak 0-3 c3-3 m[0-3]']);
      expect(_parse('*\t*\t*\t'), <String>['thematicBreak 0-6 c6-6 m[0-6]']);
    },
  );

  test('a four space indented line is paragraph text', () {
    expect(_parse('    foo'), <String>['paragraph 0-7 c4-7 m[0-4]']);
    expect(_parse('Foo\n    bar'), <String>['paragraph 0-11 c0-11 m[4-8]']);
    expect(_parse('    foo\nbar'), <String>['paragraph 0-11 c4-11 m[0-4]']);
    expect(_parse('    # foo'), <String>['paragraph 0-9 c4-9 m[0-4]']);
    expect(_parse('    ***'), <String>['paragraph 0-7 c4-7 m[0-4]']);
    expect(_parse('\tfoo'), <String>['paragraph 0-4 c1-4 m[0-1]']);
  });

  test('a crlf counts as one line break and a lone cr is content', () {
    expect(_split('a\r\nb'), <(int, int, int)>[(0, 1, 3), (3, 4, 4)]);
    expect(_split('a\rb'), <(int, int, int)>[(0, 3, 3)]);
    expect(_split('a\r\r\nb'), <(int, int, int)>[(0, 2, 4), (4, 5, 5)]);
    expect(_split('\r\n'), <(int, int, int)>[(0, 0, 2), (2, 2, 2)]);
    expect(_split(''), <(int, int, int)>[(0, 0, 0)]);
    expect(_split('a\n'), <(int, int, int)>[(0, 1, 2), (2, 2, 2)]);
    expect(_parse('# T\r\nx'), <String>[
      'heading1 0-3 c2-3 m[0-2]',
      'paragraph 5-6 c5-6 m[]',
    ]);
    expect(_parse('a\r\n\r\nb'), <String>[
      'paragraph 0-1 c0-1 m[]',
      'paragraph 5-6 c5-6 m[]',
    ]);
    expect(_parse('a\rb'), <String>['paragraph 0-3 c0-3 m[]']);
  });

  test('blank lines separate blocks and make no node', () {
    expect(_parse(''), isEmpty);
    expect(_parse('  '), isEmpty);
    expect(_parse('a\n'), <String>['paragraph 0-1 c0-1 m[]']);
    expect(_parse('A\n\n\nB'), <String>[
      'paragraph 0-1 c0-1 m[]',
      'paragraph 4-5 c4-5 m[]',
    ]);
    expect(_parse('# a\n\n'), <String>['heading1 0-3 c2-3 m[0-2]']);
    expect(_parse('A\n  \nB'), <String>[
      'paragraph 0-1 c0-1 m[]',
      'paragraph 5-6 c5-6 m[]',
    ]);
  });

  test('a caret inside a separator lies in no block', () {
    final List<MdBlock> blocks = _parser.parse('A\n\nB');
    final MdTree tree = MdTree(sourceLength: 4, blocks: blocks);
    expect(tree.blockAt(2), isNull);
    expect(tree.blockAt(1), same(blocks[0]));
    expect(tree.blockAt(3), same(blocks[1]));
  });

  test('hashes without a following space are paragraph text', () {
    expect(_parse('#5 bolt'), <String>['paragraph 0-7 c0-7 m[]']);
    expect(_parse('#hashtag'), <String>['paragraph 0-8 c0-8 m[]']);
    expect(_parse(r'\## foo'), <String>['paragraph 0-7 c0-7 m[]']);
  });

  test('paragraph whitespace is recorded as markers', () {
    expect(_parse('foo  '), <String>['paragraph 0-5 c0-3 m[3-5]']);
    expect(_parse('  aaa\n bbb'), <String>['paragraph 0-10 c2-10 m[0-2 6-7]']);
    expect(_parse('aaa     \nbbb     '), <String>[
      'paragraph 0-17 c0-12 m[12-17]',
    ]);
  });

  test('inline segments skip line breaks and markers', () {
    const String indented = '  aaa\n bbb';
    expect(
      MdBlockParser.inlineSegments(
        MdSourceLines.split(indented),
        _parser.parse(indented).single,
        const <MdBlock>[],
      ),
      <MdRange>[const MdRange(2, 5), const MdRange(7, 10)],
    );
    const String trailing = 'aaa     \nbbb     ';
    expect(
      MdBlockParser.inlineSegments(
        MdSourceLines.split(trailing),
        _parser.parse(trailing).single,
        const <MdBlock>[],
      ),
      <MdRange>[const MdRange(0, 8), const MdRange(9, 12)],
    );
    expect(
      MdBlockParser.inlineSegments(
        MdSourceLines.split('## '),
        _parser.parse('## ').single,
        const <MdBlock>[],
      ),
      isEmpty,
    );
  });

  test('lineIndexAt maps offsets to lines', () {
    final MdSourceLines lines = MdSourceLines.split('ab\r\ncd\nef');
    expect(lines.lineIndexAt(0), 0);
    expect(lines.lineIndexAt(4), 1);
    expect(lines.lineIndexAt(3), 0);
    expect(lines.lineIndexAt(9), 2);
    expect(() => lines.lineIndexAt(-1), throwsRangeError);
    expect(() => lines.lineIndexAt(10), throwsRangeError);
  });

  test('the line cursor counts tab stops and keeps virtual columns', () {
    expect(
      MdLineCursor.atLine(MdSourceLines.split(' \tx'), 0).indentColumns,
      4,
    );
    final MdLineCursor cursor = MdLineCursor.atLine(
      MdSourceLines.split('\tx'),
      0,
    ).consumeColumns(2);
    expect(cursor.offset, 1);
    expect(cursor.column, 2);
    expect(cursor.virtualColumns, 2);
    expect(cursor.indentColumns, 2);
    expect(cursor.codeUnit, 0x78);
    expect(cursor.skipSpaces().column, 4);
    expect(cursor.advance(1).offset, 2);
    expect(cursor.advance(1).codeUnit, isNull);
    expect(cursor.advance(1).restIsBlank, isTrue);
  });

  test('parse results are unmodifiable', () {
    final List<MdBlock> blocks = _parser.parse('# a\n\nb  ');
    expect(() => blocks.add(blocks.first), throwsA(isA<UnsupportedError>()));
    for (final MdBlock block in blocks) {
      expect(
        () => block.markerRanges.add(const MdRange(0, 0)),
        throwsA(isA<UnsupportedError>()),
      );
    }
    expect(
      () => MdSourceLines.split(
        'a',
      ).lines.add(const MdSourceLine(index: 1, start: 1, end: 1, breakEnd: 1)),
      throwsA(isA<UnsupportedError>()),
    );
  });

  test('large sources parse without throwing', () {
    final StringBuffer buffer = StringBuffer();
    final String joined = noteFuzzCorpus.join('\n\n');
    while (buffer.length < 100000) {
      buffer.write(joined);
      buffer.write('\n\n');
    }
    final String large = buffer.toString().substring(0, 100000);
    expect(large.length, 100000);
    expect(() => _parser.parse(large), returnsNormally);
    final String line = 'a' * 30000;
    expect(_parse(line), <String>['paragraph 0-30000 c0-30000 m[]']);
  });

  test('parse never throws on odd strings', () {
    for (final String source in <String>[
      '\u0000',
      'a\uD800b',
      '\uDC00\n# \uD800',
      '\r\r\r',
    ]) {
      expect(() => _checkInvariants(source), returnsNormally);
    }
  });

  test('parse invariants hold over the fuzz corpus', () {
    for (final String source in noteFuzzCorpus) {
      _checkInvariants(source);
    }
  });

  test('parse invariants hold over seeded generated sources', () {
    for (final String source in _generatedSources()) {
      _checkInvariants(source);
    }
  });
}
