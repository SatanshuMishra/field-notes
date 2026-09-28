import 'package:field_notes/domain/notes/markdown/block_parser.dart';
import 'package:field_notes/domain/notes/markdown/blocks/list_items.dart';
import 'package:field_notes/domain/notes/markdown/source_lines.dart';
import 'package:field_notes/domain/notes/markdown/syntax_tree.dart';
import 'package:flutter_test/flutter_test.dart';

const MdBlockParser _parser = MdBlockParser();

String _range(MdRange range) => '${range.start}-${range.end}';

String _tight(bool isTight) => isTight ? 'tight' : 'loose';

String _data(MdBlockData? data) => switch (data) {
  MdBulletListData() => ' bullet(${data.bullet},${_tight(data.isTight)})',
  MdOrderedListData() =>
    ' ordered(${data.start},${data.delimiter.name},${_tight(data.isTight)})',
  MdListItemData(taskState: MdTaskState.none) => '',
  MdListItemData() =>
    ' task(${data.taskState.name},${_range(data.taskBoxRange!)})',
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

MdListMarker? _marker(String source) =>
    MdListItems.markerAt(MdLineCursor.atLine(MdSourceLines.split(source), 0));

bool _isLoose(MdBlock list, String source) =>
    MdListItems.isLoose(list, MdSourceLines.split(source));

MdListItemData _itemData(String source) =>
    _parser.parse(source).single.blocks.single.data! as MdListItemData;

int _listDepth(MdBlock block) {
  int deepest = 0;
  for (final MdBlock child in block.blocks) {
    final int depth = _listDepth(child);
    if (depth > deepest) {
      deepest = depth;
    }
  }
  return block.kind == MdBlockKind.bulletList ? deepest + 1 : deepest;
}

void main() {
  test(
    'nested lists follow commonmark content columns including the five space rule',
    () {
      expect(_parse('- a\n  - b\n    - c'), <String>[
        'bulletList 0-17 c0-17 m[] bullet(-,tight)',
        '  listItem 0-17 c2-17 m[0-2 4-6 10-12]',
        '    paragraph 2-3 c2-3 m[]',
        '    bulletList 6-17 c6-17 m[] bullet(-,tight)',
        '      listItem 6-17 c8-17 m[6-8 12-14]',
        '        paragraph 8-9 c8-9 m[]',
        '        bulletList 14-17 c14-17 m[] bullet(-,tight)',
        '          listItem 14-17 c16-17 m[14-16]',
        '            paragraph 16-17 c16-17 m[]',
      ]);
      expect(_parse('- a\n - b\n  - c\n   - d'), <String>[
        'bulletList 0-21 c0-21 m[] bullet(-,tight)',
        '  listItem 0-3 c2-3 m[0-2]',
        '    paragraph 2-3 c2-3 m[]',
        '  listItem 4-8 c7-8 m[4-7]',
        '    paragraph 7-8 c7-8 m[]',
        '  listItem 9-14 c13-14 m[9-13]',
        '    paragraph 13-14 c13-14 m[]',
        '  listItem 15-21 c20-21 m[15-20]',
        '    paragraph 20-21 c20-21 m[]',
      ]);
      expect(_parse('-     a\n\n  b'), <String>[
        'bulletList 0-12 c0-12 m[] bullet(-,loose)',
        '  listItem 0-12 c2-12 m[0-2 9-11]',
        '    paragraph 2-7 c6-7 m[2-6]',
        '    paragraph 11-12 c11-12 m[]',
      ]);
      expect(_parse('-    a\n\n  b'), <String>[
        'bulletList 0-6 c0-6 m[] bullet(-,tight)',
        '  listItem 0-6 c5-6 m[0-5]',
        '    paragraph 5-6 c5-6 m[]',
        'paragraph 8-11 c10-11 m[8-10]',
      ]);
      expect(_parse('- a\n\t- b'), <String>[
        'bulletList 0-8 c0-8 m[] bullet(-,tight)',
        '  listItem 0-8 c2-8 m[0-2 4-5]',
        '    paragraph 2-3 c2-3 m[]',
        '    bulletList 5-8 c5-8 m[] bullet(-,tight)',
        '      listItem 5-8 c7-8 m[5-7]',
        '        paragraph 7-8 c7-8 m[]',
      ]);
      expect(_parse('- a\n    - b'), <String>[
        'bulletList 0-11 c0-11 m[] bullet(-,tight)',
        '  listItem 0-11 c2-11 m[0-2 4-6]',
        '    paragraph 2-3 c2-3 m[]',
        '    bulletList 6-11 c6-11 m[] bullet(-,tight)',
        '      listItem 6-11 c10-11 m[6-10]',
        '        paragraph 10-11 c10-11 m[]',
      ]);
    },
  );

  test('an ordered list interrupts a paragraph only when it starts at one', () {
    expect(_parse('Windows:\n14. doors'), <String>['paragraph 0-18 c0-18 m[]']);
    expect(_parse('Windows:\n1. doors'), <String>[
      'paragraph 0-8 c0-8 m[]',
      'orderedList 9-17 c9-17 m[] ordered(1,period,tight)',
      '  listItem 9-17 c12-17 m[9-12]',
      '    paragraph 12-17 c12-17 m[]',
    ]);
    expect(
      _parser.parse('Windows:\n1. doors')[1].data,
      const MdOrderedListData(
        start: 1,
        delimiter: MdListDelimiter.period,
        isTight: true,
      ),
    );
    expect(_parse('Foo\n- bar'), <String>[
      'paragraph 0-3 c0-3 m[]',
      'bulletList 4-9 c4-9 m[] bullet(-,tight)',
      '  listItem 4-9 c6-9 m[4-6]',
      '    paragraph 6-9 c6-9 m[]',
    ]);
    expect(_parse('foo\n*'), <String>['paragraph 0-5 c0-5 m[]']);
    expect(_parse('14. doors'), <String>[
      'orderedList 0-9 c0-9 m[] ordered(14,period,tight)',
      '  listItem 0-9 c4-9 m[0-4]',
      '    paragraph 4-9 c4-9 m[]',
    ]);
  });

  test('task items accept x, capital x and a space', () {
    expect(_parse('- [x] a'), <String>[
      'bulletList 0-7 c0-7 m[] bullet(-,tight)',
      '  listItem 0-7 c5-7 m[0-2 2-5] task(checked,2-5)',
      '    paragraph 5-7 c6-7 m[5-6]',
    ]);
    expect(
      _itemData('- [x] a'),
      const MdListItemData(
        taskState: MdTaskState.checked,
        taskBoxRange: MdRange(2, 5),
      ),
    );
    expect(_itemData('- [X] a').taskState, MdTaskState.checked);
    expect(_itemData('- [ ] a').taskState, MdTaskState.unchecked);
    expect(_itemData('- [\t] a').taskState, MdTaskState.unchecked);
    expect(_parse('1. [x] a'), <String>[
      'orderedList 0-8 c0-8 m[] ordered(1,period,tight)',
      '  listItem 0-8 c6-8 m[0-3 3-6] task(checked,3-6)',
      '    paragraph 6-8 c7-8 m[6-7]',
    ]);
    for (final String source in <String>[
      '- [y] a',
      '- [x]a',
      '- [x]',
      '- a\n  [x] b',
    ]) {
      expect(
        _itemData(source),
        const MdListItemData(taskState: MdTaskState.none),
        reason: source,
      );
    }
    expect(_parse('- [y] a'), <String>[
      'bulletList 0-7 c0-7 m[] bullet(-,tight)',
      '  listItem 0-7 c2-7 m[0-2]',
      '    paragraph 2-7 c2-7 m[]',
    ]);
    expect(_parse('- [ ] '), <String>[
      'bulletList 0-6 c0-6 m[] bullet(-,tight)',
      '  listItem 0-6 c5-6 m[0-2 2-5] task(unchecked,2-5)',
      '    paragraph 5-6 c6-6 m[5-6]',
    ]);
  });

  test('loose and tight lists are told apart', () {
    for (final (String source, bool loose) in <(String, bool)>[
      ('- a\n- b', false),
      ('- a\n\n- b', true),
      ('- a\n- b\n\n- c', true),
      ('- a\n- b\n\n', false),
    ]) {
      final MdBlock list = _parser.parse(source).single;
      expect(_isLoose(list, source), loose, reason: source);
      expect(
        list.data,
        MdBulletListData(bullet: '-', isTight: !loose),
        reason: source,
      );
    }
    const String nested = '- a\n  - b\n\n    c\n- d';
    final MdBlock outer = _parser.parse(nested).single;
    final MdBlock inner = outer.blocks.first.blocks[1];
    expect(_isLoose(outer, nested), isFalse);
    expect(_isLoose(inner, nested), isTrue);
    expect(outer.data, const MdBulletListData(bullet: '-', isTight: true));
    expect(inner.data, const MdBulletListData(bullet: '-', isTight: false));
  });

  test('a lazy line joins the open paragraph in a list item', () {
    expect(_parse('- eggs\nThen we left.'), <String>[
      'bulletList 0-20 c0-20 m[] bullet(-,tight)',
      '  listItem 0-20 c2-20 m[0-2]',
      '    paragraph 2-20 c2-20 m[]',
    ]);
    expect(_parse('- a\n  detail'), <String>[
      'bulletList 0-12 c0-12 m[] bullet(-,tight)',
      '  listItem 0-12 c2-12 m[0-2 4-6]',
      '    paragraph 2-12 c2-12 m[]',
    ]);
    expect(_parse('- a\n\nb'), <String>[
      'bulletList 0-3 c0-3 m[] bullet(-,tight)',
      '  listItem 0-3 c2-3 m[0-2]',
      '    paragraph 2-3 c2-3 m[]',
      'paragraph 5-6 c5-6 m[]',
    ]);
    expect(_parse('- a\n# h'), <String>[
      'bulletList 0-3 c0-3 m[] bullet(-,tight)',
      '  listItem 0-3 c2-3 m[0-2]',
      '    paragraph 2-3 c2-3 m[]',
      'heading 4-7 c6-7 m[4-6] level 1',
    ]);
    expect(_parse('> - a\nb'), <String>[
      'blockQuote 0-7 c2-7 m[0-2]',
      '  bulletList 2-7 c2-7 m[] bullet(-,tight)',
      '    listItem 2-7 c4-7 m[2-4]',
      '      paragraph 4-7 c4-7 m[]',
    ]);
  });

  test('lists inside quotes count columns from the quote content', () {
    expect(_parse('> - x'), <String>[
      'blockQuote 0-5 c2-5 m[0-2]',
      '  bulletList 2-5 c2-5 m[] bullet(-,tight)',
      '    listItem 2-5 c4-5 m[2-4]',
      '      paragraph 4-5 c4-5 m[]',
    ]);
    expect(_parse('> 1. a\n> 2. b'), <String>[
      'blockQuote 0-13 c2-13 m[0-2 7-9]',
      '  orderedList 2-13 c2-13 m[] ordered(1,period,tight)',
      '    listItem 2-6 c5-6 m[2-5]',
      '      paragraph 5-6 c5-6 m[]',
      '    listItem 9-13 c12-13 m[9-12]',
      '      paragraph 12-13 c12-13 m[]',
    ]);
    expect(_parse('>- a\n>  - b'), <String>[
      'blockQuote 0-11 c1-11 m[0-1 5-7]',
      '  bulletList 1-11 c1-11 m[] bullet(-,tight)',
      '    listItem 1-4 c3-4 m[1-3]',
      '      paragraph 3-4 c3-4 m[]',
      '    listItem 7-11 c10-11 m[7-10]',
      '      paragraph 10-11 c10-11 m[]',
    ]);
    expect(_parse('>- a\n>   - b'), <String>[
      'blockQuote 0-12 c1-12 m[0-1 5-7]',
      '  bulletList 1-12 c1-12 m[] bullet(-,tight)',
      '    listItem 1-12 c3-12 m[1-3 7-9]',
      '      paragraph 3-4 c3-4 m[]',
      '      bulletList 9-12 c9-12 m[] bullet(-,tight)',
      '        listItem 9-12 c11-12 m[9-11]',
      '          paragraph 11-12 c11-12 m[]',
    ]);
  });

  test('bullets and delimiters group items into lists', () {
    expect(_parse('1. a\n1. b'), <String>[
      'orderedList 0-9 c0-9 m[] ordered(1,period,tight)',
      '  listItem 0-4 c3-4 m[0-3]',
      '    paragraph 3-4 c3-4 m[]',
      '  listItem 5-9 c8-9 m[5-8]',
      '    paragraph 8-9 c8-9 m[]',
    ]);
    expect(_parse('1. a\n2) b'), <String>[
      'orderedList 0-4 c0-4 m[] ordered(1,period,tight)',
      '  listItem 0-4 c3-4 m[0-3]',
      '    paragraph 3-4 c3-4 m[]',
      'orderedList 5-9 c5-9 m[] ordered(2,paren,tight)',
      '  listItem 5-9 c8-9 m[5-8]',
      '    paragraph 8-9 c8-9 m[]',
    ]);
    expect(_parse('- a\n+ b'), <String>[
      'bulletList 0-3 c0-3 m[] bullet(-,tight)',
      '  listItem 0-3 c2-3 m[0-2]',
      '    paragraph 2-3 c2-3 m[]',
      'bulletList 4-7 c4-7 m[] bullet(+,tight)',
      '  listItem 4-7 c6-7 m[4-6]',
      '    paragraph 6-7 c6-7 m[]',
    ]);
  });

  test('a lazy or sibling line may start any ordered item', () {
    expect(_parse('> a\n14. b'), <String>[
      'blockQuote 0-3 c2-3 m[0-2]',
      '  paragraph 2-3 c2-3 m[]',
      'orderedList 4-9 c4-9 m[] ordered(14,period,tight)',
      '  listItem 4-9 c8-9 m[4-8]',
      '    paragraph 8-9 c8-9 m[]',
    ]);
    expect(_parse('- a\n  14. b'), <String>[
      'bulletList 0-11 c0-11 m[] bullet(-,tight)',
      '  listItem 0-11 c2-11 m[0-2 4-6]',
      '    paragraph 2-11 c2-11 m[]',
    ]);
  });

  test('marker forms follow commonmark', () {
    expect(_parse('- - -'), <String>['thematicBreak 0-5 c5-5 m[0-5]']);
    expect(_parse('* * *'), <String>['thematicBreak 0-5 c5-5 m[0-5]']);
    expect(_parse('-one'), <String>['paragraph 0-4 c0-4 m[]']);
    expect(_parse('2.two'), <String>['paragraph 0-5 c0-5 m[]']);
    expect(_parse('1234567890. not ok'), <String>['paragraph 0-18 c0-18 m[]']);
    expect(
      (_parser.parse('003. ok').single.data! as MdOrderedListData).start,
      3,
    );
    expect((_parser.parse('0. ok').single.data! as MdOrderedListData).start, 0);
    expect(
      (_parser.parse('123456789. ok').single.data! as MdOrderedListData).start,
      123456789,
    );
  });

  test('an item may start blank and hold at most one blank line first', () {
    expect(_parse('-\n  foo'), <String>[
      'bulletList 0-7 c0-7 m[] bullet(-,tight)',
      '  listItem 0-7 c4-7 m[0-1 2-4]',
      '    paragraph 4-7 c4-7 m[]',
    ]);
    expect(_parse('-\n\n  foo'), <String>[
      'bulletList 0-1 c0-1 m[] bullet(-,tight)',
      '  listItem 0-1 c1-1 m[0-1]',
      'paragraph 3-8 c5-8 m[3-5]',
    ]);
  });

  test('a fence ends with its item', () {
    expect(_parse('- ```\n  a\nb'), <String>[
      'bulletList 0-9 c0-9 m[] bullet(-,tight)',
      '  listItem 0-9 c2-9 m[0-2 6-8]',
      '    fencedCode 2-9 c8-9 m[2-5] open',
      'paragraph 10-11 c10-11 m[]',
    ]);
    const String loose = '- ```\n  b\n\n- c';
    expect(_parse(loose), <String>[
      'bulletList 0-14 c0-14 m[] bullet(-,loose)',
      '  listItem 0-9 c2-9 m[0-2 6-8]',
      '    fencedCode 2-9 c8-9 m[2-5] open',
      '  listItem 11-14 c13-14 m[11-13]',
      '    paragraph 13-14 c13-14 m[]',
    ]);
    expect(_isLoose(_parser.parse(loose).single, loose), isTrue);
  });

  test('blank lines between items are markers of the list', () {
    const String quoted = '* a\n  > b\n  >\n* c';
    expect(_parse(quoted), <String>[
      'bulletList 0-17 c0-17 m[] bullet(*,tight)',
      '  listItem 0-13 c2-13 m[0-2 4-6 10-12]',
      '    paragraph 2-3 c2-3 m[]',
      '    blockQuote 6-13 c8-9 m[6-8 12-13]',
      '      paragraph 8-9 c8-9 m[]',
      '  listItem 14-17 c16-17 m[14-16]',
      '    paragraph 16-17 c16-17 m[]',
    ]);
    expect(_isLoose(_parser.parse(quoted).single, quoted), isFalse);
    const String spaced = '- a\n  \n- b';
    expect(_parse(spaced), <String>[
      'bulletList 0-10 c0-10 m[4-6] bullet(-,loose)',
      '  listItem 0-3 c2-3 m[0-2]',
      '    paragraph 2-3 c2-3 m[]',
      '  listItem 7-10 c9-10 m[7-9]',
      '    paragraph 9-10 c9-10 m[]',
    ]);
    expect(_isLoose(_parser.parse(spaced).single, spaced), isTrue);
  });

  test('five spaces before a task box make one more item marker', () {
    expect(_parse('-     [x] a'), <String>[
      'bulletList 0-11 c0-11 m[] bullet(-,tight)',
      '  listItem 0-11 c9-11 m[0-2 2-6 6-9] task(checked,6-9)',
      '    paragraph 9-11 c10-11 m[9-10]',
    ]);
  });

  test('a marker-only line keeps the commonmark reading', () {
    expect(_parse('- a\n  - '), <String>[
      'bulletList 0-8 c0-8 m[] bullet(-,tight)',
      '  listItem 0-8 c2-8 m[0-2 4-6]',
      '    paragraph 2-8 c2-7 m[7-8]',
    ]);
    expect(_parse('- a\n- '), <String>[
      'bulletList 0-6 c0-6 m[] bullet(-,tight)',
      '  listItem 0-3 c2-3 m[0-2]',
      '    paragraph 2-3 c2-3 m[]',
      '  listItem 4-6 c6-6 m[4-6]',
    ]);
  });

  test('a list nested ten levels deep parses every level', () {
    final String source = List<String>.generate(
      10,
      (int level) => '${'  ' * level}- a',
    ).join('\n');
    expect(_listDepth(_parser.parse(source).single), 10);
  });

  test('the marker reader reports content columns', () {
    expect(_marker('- a')!.contentColumn, 2);
    expect(_marker('-    a')!.contentColumn, 5);
    expect(_marker('-     a')!.contentColumn, 2);
    expect(_marker('1.  a')!.contentColumn, 4);
    expect(
      _marker('-'),
      const MdListMarker(
        ordered: false,
        character: 0x2D,
        start: 0,
        range: MdRange(0, 1),
        contentColumn: 2,
        startsBlank: true,
      ),
    );
    expect(
      _marker('  12) x'),
      const MdListMarker(
        ordered: true,
        character: 0x29,
        start: 12,
        range: MdRange(0, 5),
        contentColumn: 6,
        startsBlank: false,
      ),
    );
    expect(_marker('-one'), isNull);
    expect(_marker('    - a'), isNull);
  });

  test('inline segments of an item paragraph skip the item markers', () {
    const String source = '- a\n  detail';
    final MdBlock list = _parser.parse(source).single;
    final MdBlock item = list.blocks.single;
    expect(
      MdBlockParser.inlineSegments(
        MdSourceLines.split(source),
        item.blocks.single,
        <MdBlock>[list, item],
      ),
      <MdRange>[const MdRange(2, 3), const MdRange(6, 12)],
    );
  });
}
