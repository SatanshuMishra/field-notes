import 'package:field_notes/domain/notes/markdown/block_parser.dart';
import 'package:field_notes/domain/notes/markdown/blocks/tables.dart';
import 'package:field_notes/domain/notes/markdown/source_lines.dart';
import 'package:field_notes/domain/notes/markdown/syntax_tree.dart';
import 'package:flutter_test/flutter_test.dart';

const MdBlockParser _parser = MdBlockParser();

const String _photo = '![p](photo/abc123abc123)';

String _range(MdRange range) => '${range.start}-${range.end}';

String _data(MdBlockData? data) => switch (data) {
  MdTableCellData() => ' ${data.alignment.name}',
  MdOrderedListData() => ' start ${data.start}',
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

List<String> _parse(String source, {bool tables = true}) =>
    _render(MdBlockParser(tables: tables).parse(source));

List<String> _topLevel(String source, {bool tables = true}) => <String>[
  for (final MdBlock block in MdBlockParser(tables: tables).parse(source))
    '${block.kind.name} ${_range(block.sourceRange)}',
];

Iterable<MdBlock> _allBlocks(List<MdBlock> blocks) sync* {
  for (final MdBlock block in blocks) {
    yield block;
    yield* _allBlocks(block.blocks);
  }
}

List<MdTableCellSpan> _split(String row) =>
    MdTables.splitRow(row, MdRange(0, row.length));

List<MdCellAlignment>? _alignments(String row) =>
    MdTables.delimiterAlignments(row, MdRange(0, row.length));

void _expectRowCoverage(String source) {
  for (final MdBlock row in _allBlocks(
    _parser.parse(source),
  ).where((MdBlock block) => block.kind == MdBlockKind.tableRow)) {
    for (int at = row.sourceRange.start; at < row.sourceRange.end; at++) {
      final int holders =
          row.blocks
              .where((MdBlock cell) => cell.sourceRange.contains(at))
              .length +
          row.markerRanges
              .where((MdRange marker) => marker.contains(at))
              .length;
      expect(holders, 1, reason: '$source at $at');
    }
  }
}

void main() {
  test('a table header may be the last line of a paragraph', () {
    expect(_parse('A\n| a |\n| - |'), <String>[
      'paragraph 0-1 c0-1 m[]',
      'table 2-13 c2-7 m[8-13]',
      '  tableRow 2-7 c2-7 m[2-3 6-7]',
      '    tableCell 3-6 c4-5 m[3-4 5-6] none',
    ]);
    expect(_parse('A\nB\n| a | b |\n| - | - |\n| 1 | 2 |'), <String>[
      'paragraph 0-3 c0-3 m[]',
      'table 4-33 c4-33 m[14-23]',
      '  tableRow 4-13 c4-13 m[4-5 8-9 12-13]',
      '    tableCell 5-8 c6-7 m[5-6 7-8] none',
      '    tableCell 9-12 c10-11 m[9-10 11-12] none',
      '  tableRow 24-33 c24-33 m[24-25 28-29 32-33]',
      '    tableCell 25-28 c26-27 m[25-26 27-28] none',
      '    tableCell 29-32 c30-31 m[29-30 31-32] none',
    ]);
    expect(_parse('a | b\n-|-'), <String>[
      'table 0-9 c0-5 m[6-9]',
      '  tableRow 0-5 c0-5 m[2-3]',
      '    tableCell 0-2 c0-1 m[1-2] none',
      '    tableCell 3-5 c4-5 m[3-4] none',
    ]);
    expect(_topLevel('| a | b |\n| - |'), <String>['paragraph 0-15']);
    expect(_topLevel('a\n| - |'), <String>['paragraph 0-7']);
  });

  test(
    'a non blank line after a table is a body row unless it starts a block',
    () {
      expect(_parse('| a |\n| - |\n| b |\nc'), <String>[
        'table 0-19 c0-19 m[6-11]',
        '  tableRow 0-5 c0-5 m[0-1 4-5]',
        '    tableCell 1-4 c2-3 m[1-2 3-4] none',
        '  tableRow 12-17 c12-17 m[12-13 16-17]',
        '    tableCell 13-16 c14-15 m[13-14 15-16] none',
        '  tableRow 18-19 c18-19 m[]',
        '    tableCell 18-19 c18-19 m[] none',
      ]);
      for (final (String ender, String kind) in <(String, String)>[
        ('> q', 'blockQuote'),
        ('# h', 'heading'),
        ('```', 'fencedCode'),
        ('---', 'thematicBreak'),
        ('- x', 'bulletList'),
      ]) {
        expect(_topLevel('| a |\n| - |\n$ender'), <String>[
          'table 0-11',
          '$kind 12-15',
        ], reason: ender);
      }
      expect(_topLevel('| a |\n| - |\n\nc'), <String>[
        'table 0-11',
        'paragraph 13-14',
      ]);
      final List<MdBlock> photo = _parser.parse('| a |\n| - |\n| b |\n$_photo');
      expect(_topLevel('| a |\n| - |\n| b |\n$_photo'), <String>[
        'table 0-17',
        'photoLine 18-42',
      ]);
      expect(photo.first.blocks.length, 2);
    },
  );

  test('table syntax inside a quote or list item is paragraph text', () {
    expect(_parse('> | a |\n> | - |'), <String>[
      'blockQuote 0-15 c2-15 m[0-2 8-10]',
      '  paragraph 2-15 c2-15 m[]',
    ]);
    expect(_parse('- | a |\n  | - |'), <String>[
      'bulletList 0-15 c0-15 m[]',
      '  listItem 0-15 c2-15 m[0-2 8-10]',
      '    paragraph 2-15 c2-15 m[]',
    ]);
    for (final String source in <String>[
      '> | a |\n> | - |',
      '- | a |\n  | - |',
    ]) {
      expect(
        _allBlocks(
          _parser.parse(source),
        ).where((MdBlock block) => block.kind == MdBlockKind.table),
        isEmpty,
      );
    }
    expect(_topLevel('| a |\n| - |'), <String>['table 0-11']);
  });

  test('tables are paragraph text when the tables option is off', () {
    const String source = '| a |\n| - |\n| b |';
    expect(_render(const MdBlockParser(tables: false).parse(source)), <String>[
      'paragraph 0-17 c0-17 m[]',
    ]);
    expect(_render(const MdBlockParser().parse(source)), <String>[
      'table 0-17 c0-17 m[6-11]',
      '  tableRow 0-5 c0-5 m[0-1 4-5]',
      '    tableCell 1-4 c2-3 m[1-2 3-4] none',
      '  tableRow 12-17 c12-17 m[12-13 16-17]',
      '    tableCell 13-16 c14-15 m[13-14 15-16] none',
    ]);
  });

  test('alignment follows the delimiter row', () {
    expect(_parse('| a | b |\n|:-|-:|\n| 1 |  |'), <String>[
      'table 0-26 c0-26 m[10-17]',
      '  tableRow 0-9 c0-9 m[0-1 4-5 8-9]',
      '    tableCell 1-4 c2-3 m[1-2 3-4] left',
      '    tableCell 5-8 c6-7 m[5-6 7-8] right',
      '  tableRow 18-26 c18-26 m[18-19 22-23 25-26]',
      '    tableCell 19-22 c20-21 m[19-20 21-22] left',
      '    tableCell 23-25 c24-24 m[23-24 24-25] right',
    ]);
    expect(_alignments('|:-:|'), <MdCellAlignment>[MdCellAlignment.centre]);
    expect(_alignments('| --- | :-- | --: | :-: |'), <MdCellAlignment>[
      MdCellAlignment.none,
      MdCellAlignment.left,
      MdCellAlignment.right,
      MdCellAlignment.centre,
    ]);
  });

  test('missing cells get no node and extra cells are row markers', () {
    expect(_parse('| a | b |\n| - | - |\n| 1 | 2 | 3 |'), <String>[
      'table 0-33 c0-33 m[10-19]',
      '  tableRow 0-9 c0-9 m[0-1 4-5 8-9]',
      '    tableCell 1-4 c2-3 m[1-2 3-4] none',
      '    tableCell 5-8 c6-7 m[5-6 7-8] none',
      '  tableRow 20-33 c20-33 m[20-21 24-25 28-29 29-32 32-33]',
      '    tableCell 21-24 c22-23 m[21-22 23-24] none',
      '    tableCell 25-28 c26-27 m[25-26 27-28] none',
    ]);
    expect(_parse('| a | b |\n| - | - |\n| 1 |'), <String>[
      'table 0-25 c0-25 m[10-19]',
      '  tableRow 0-9 c0-9 m[0-1 4-5 8-9]',
      '    tableCell 1-4 c2-3 m[1-2 3-4] none',
      '    tableCell 5-8 c6-7 m[5-6 7-8] none',
      '  tableRow 20-25 c20-25 m[20-21 24-25]',
      '    tableCell 21-24 c22-23 m[21-22 23-24] none',
    ]);
  });

  test('escaped pipes stay in their cell as markers', () {
    const String source = '| x \\| y |\n| - |';
    expect(_parse(source), <String>[
      'table 0-16 c0-10 m[11-16]',
      '  tableRow 0-10 c0-10 m[0-1 9-10]',
      '    tableCell 1-9 c2-8 m[1-2 4-5 8-9] none',
    ]);
    final MdBlock table = _parser.parse(source).single;
    final MdBlock row = table.blocks.single;
    expect(
      MdBlockParser.inlineSegments(
        MdSourceLines.split(source),
        row.blocks.single,
        <MdBlock>[table, row],
      ),
      <MdRange>[const MdRange(2, 4), const MdRange(5, 8)],
    );
  });

  test('gfm example 200 keeps its escaped pipes as cell markers', () {
    const String source =
        '| f\\|oo  |\n| ------ |\n| b `\\|` az |\n| b **\\|** im |';
    expect(source.length, 51);
    expect(_parse(source), <String>[
      'table 0-51 c0-51 m[11-21]',
      '  tableRow 0-10 c0-10 m[0-1 9-10]',
      '    tableCell 1-9 c2-7 m[1-2 3-4 7-9] none',
      '  tableRow 22-35 c22-35 m[22-23 34-35]',
      '    tableCell 23-34 c24-33 m[23-24 27-28 33-34] none',
      '  tableRow 36-51 c36-51 m[36-37 50-51]',
      '    tableCell 37-50 c38-49 m[37-38 42-43 49-50] none',
    ]);
  });

  test('block starts come before the delimiter row', () {
    expect(_parse('a | b\n- | - |'), <String>[
      'paragraph 0-5 c0-5 m[]',
      'bulletList 6-13 c6-13 m[]',
      '  listItem 6-13 c8-13 m[6-8]',
      '    paragraph 8-13 c8-13 m[]',
    ]);
    expect(_parse('a | b\n    - | -'), <String>[
      'paragraph 0-15 c0-15 m[6-10]',
    ]);
    expect(_parse('| a |\n| - |\n14. x'), <String>[
      'table 0-11 c0-5 m[6-11]',
      '  tableRow 0-5 c0-5 m[0-1 4-5]',
      '    tableCell 1-4 c2-3 m[1-2 3-4] none',
      'orderedList 12-17 c12-17 m[] start 14',
      '  listItem 12-17 c16-17 m[12-16]',
      '    paragraph 16-17 c16-17 m[]',
    ]);
    expect(_topLevel('| a |\n---'), <String>[
      'paragraph 0-5',
      'thematicBreak 6-9',
    ]);
    expect(_parse('| a |\r\n| - |'), <String>[
      'table 0-12 c0-5 m[7-12]',
      '  tableRow 0-5 c0-5 m[0-1 4-5]',
      '    tableCell 1-4 c2-3 m[1-2 3-4] none',
    ]);
  });

  test('the row helpers split cells, read alignments and find escapes', () {
    expect(_split('| a | b |'), <MdTableCellSpan>[
      const MdTableCellSpan(source: MdRange(1, 4), content: MdRange(2, 3)),
      const MdTableCellSpan(source: MdRange(5, 8), content: MdRange(6, 7)),
    ]);
    expect(_split('a | b'), <MdTableCellSpan>[
      const MdTableCellSpan(source: MdRange(0, 2), content: MdRange(0, 1)),
      const MdTableCellSpan(source: MdRange(3, 5), content: MdRange(4, 5)),
    ]);
    expect(_split('|  |'), <MdTableCellSpan>[
      const MdTableCellSpan(source: MdRange(1, 3), content: MdRange(2, 2)),
    ]);
    expect(_split('||'), <MdTableCellSpan>[
      const MdTableCellSpan(source: MdRange(1, 1), content: MdRange(1, 1)),
    ]);
    expect(_split('|'), isEmpty);
    expect(_split(r'| a \\| b |'), <MdTableCellSpan>[
      const MdTableCellSpan(source: MdRange(1, 10), content: MdRange(2, 9)),
    ]);
    expect(_alignments('| a |'), isNull);
    expect(_alignments('---'), isNull);
    expect(_alignments('    | - |'), isNull);
    expect(_alignments('|-|-:|'), <MdCellAlignment>[
      MdCellAlignment.none,
      MdCellAlignment.right,
    ]);
    const String escaped = r'a\|b\\c\|';
    expect(MdTables.pipeEscapes(escaped, const MdRange(0, 9)), <MdRange>[
      const MdRange(1, 2),
      const MdRange(7, 8),
    ]);
  });

  test('every row code unit lies in one cell or one row marker', () {
    for (final String source in <String>[
      'A\n| a |\n| - |',
      'a | b\n-|-',
      '| a | b |\n|:-|-:|\n| 1 |  |',
      '| a | b |\n| - | - |\n| 1 | 2 | 3 |',
      '| a | b |\n| - | - |\n| 1 |',
      '| x \\| y |\n| - |',
      '| f\\|oo  |\n| ------ |\n| b `\\|` az |\n| b **\\|** im |',
      '  | a |  \n| - |\n  c  \n|\n| |x||',
    ]) {
      _expectRowCoverage(source);
    }
  });

  test('with tables off every ender and the photo example stay as written', () {
    for (final (String ender, String kind) in <(String, String)>[
      ('> q', 'blockQuote'),
      ('# h', 'heading'),
      ('```', 'fencedCode'),
      ('---', 'thematicBreak'),
      ('- x', 'bulletList'),
    ]) {
      expect(_topLevel('| a |\n| - |\n$ender', tables: false), <String>[
        'paragraph 0-11',
        '$kind 12-15',
      ], reason: ender);
    }
    expect(_topLevel('| a |\n| - |\n| b |\n$_photo', tables: false), <String>[
      'paragraph 0-17',
      'photoLine 18-42',
    ]);
  });
}
