import 'package:field_notes/domain/notes/markdown/note_tree.dart';
import 'package:field_notes/domain/notes/markdown/plain_text.dart';
import 'package:field_notes/domain/notes/markdown/source_lines.dart';
import 'package:field_notes/domain/notes/markdown/syntax_tree.dart';
import 'package:flutter_test/flutter_test.dart';

import '../note_fuzz_corpus.dart';

const String _photo = '![p](photo/abc123abc123)';

String _range(MdRange range) => '[${range.start},${range.end})';

Iterable<MdNode> _nodes(List<MdNode> roots) sync* {
  for (final MdNode node in roots) {
    yield node;
    yield* _nodes(node.children);
  }
}

List<MdRange> _merged(Iterable<MdRange> ranges) {
  final List<MdRange> sorted = <MdRange>[
    for (final MdRange range in ranges)
      if (!range.isEmpty) range,
  ]..sort((MdRange a, MdRange b) => a.start.compareTo(b.start));
  return sorted.fold(<MdRange>[], (List<MdRange> merged, MdRange range) {
    if (merged.isEmpty || range.start > merged.last.end) {
      return <MdRange>[...merged, range];
    }
    final MdRange last = merged.last;
    return <MdRange>[
      ...merged.take(merged.length - 1),
      MdRange(last.start, range.end > last.end ? range.end : last.end),
    ];
  });
}

List<MdRange> _allMarkers(MdTree tree) => _merged(<MdRange>[
  for (final MdNode node in _nodes(tree.blocks)) ...node.markerRanges,
]);

List<String> _markerList(String source) =>
    _allMarkers(parseNoteTree(source)).map(_range).toList();

final class _Shaper {
  _Shaper(this.source, this.tree) : markers = _allMarkers(tree);

  final String source;
  final MdTree tree;
  final List<MdRange> markers;

  String text(MdRange range) {
    final StringBuffer buffer = StringBuffer();
    int position = range.start;
    for (final MdRange marker in markers) {
      if (marker.end <= position || marker.start >= range.end) {
        continue;
      }
      if (marker.start > position) {
        buffer.write(source.substring(position, marker.start));
      }
      position = marker.end;
    }
    if (position < range.end) {
      buffer.write(source.substring(position, range.end));
    }
    return buffer.toString();
  }

  List<String> blocks(List<MdBlock> blocks) => <String>[
    for (final MdBlock block in blocks) this.block(block),
  ];

  String block(MdBlock block) {
    final MdBlockData? data = block.data;
    final String attributes = switch (data) {
      MdHeadingData() => '(${data.level})',
      MdBulletListData() => '(${data.bullet})',
      MdOrderedListData() =>
        '(${data.start}, '
            '${data.delimiter == MdListDelimiter.period ? '.' : ')'})',
      MdListItemData() =>
        data.taskState == MdTaskState.none ? '' : '(${data.taskState.name})',
      MdFenceData() => data.isClosed ? '(closed)' : '(not closed)',
      _ => '',
    };
    final List<String> children = switch (block.kind) {
      MdBlockKind.fencedCode => <String>["code '${text(block.contentRange)}'"],
      _ when block.blocks.isNotEmpty => blocks(block.blocks),
      _ => inlines(block.inlines),
    };
    return '${block.kind.name}$attributes'
        '${children.isEmpty ? '' : '[${children.join(', ')}]'}';
  }

  List<String> inlines(List<MdInline> inlines) {
    final List<String> shapes = <String>[];
    String? pendingText;
    for (final MdInline inline in inlines) {
      if (inline.kind == MdInlineKind.text) {
        pendingText = '${pendingText ?? ''}${text(inline.contentRange)}';
        continue;
      }
      if (pendingText != null) {
        shapes.add("text '$pendingText'");
        pendingText = null;
      }
      shapes.add(this.inline(inline));
    }
    if (pendingText != null) {
      shapes.add("text '$pendingText'");
    }
    return shapes;
  }

  String inline(MdInline inline) {
    final MdInlineData? data = inline.data;
    final String head = switch (inline.kind) {
      MdInlineKind.escape || MdInlineKind.codeSpan =>
        "${inline.kind.name} '${text(inline.sourceRange)}'",
      MdInlineKind.link when data is MdLinkData =>
        "link('${data.destination}'"
            "${data.title == null ? '' : ", '${data.title}'"})",
      MdInlineKind.autolink when data is MdAutolinkData =>
        "autolink(${data.kind.name}, '${data.target}')",
      _ => inline.kind.name,
    };
    final List<String> children = inlines(inline.children);
    return '$head${children.isEmpty ? '' : '[${children.join(', ')}]'}';
  }
}

List<String> _shape(String source) {
  final MdTree tree = parseNoteTree(source);
  return _Shaper(source, tree).blocks(tree.blocks);
}

List<String> _kinds(String source, {bool tables = true}) => <String>[
  for (final MdBlock block in parseNoteTree(source, tables: tables).blocks)
    block.kind.name,
];

bool _inside(MdRange inner, MdRange outer) =>
    inner.start >= outer.start && inner.end <= outer.end;

void _checkWalk(String source, bool tables, String reason) {
  final MdTree tree = parseNoteTree(source, tables: tables);
  plainTextOfTree(tree, source);
  final MdSourceLines lines = MdSourceLines.split(source);
  final Set<int> lineStarts = <int>{
    for (final MdSourceLine line in lines.lines) line.start,
  };
  final Set<int> lineEnds = <int>{
    for (final MdSourceLine line in lines.lines) line.end,
  };
  final MdRange whole = MdRange(0, source.length);
  final MdRange empty = const MdRange(0, 0);
  final MdBlock probeBlock = MdBlock(
    kind: MdBlockKind.paragraph,
    sourceRange: empty,
    contentRange: empty,
  );
  final MdInline probeInline = MdInline(
    kind: MdInlineKind.text,
    sourceRange: empty,
    contentRange: empty,
  );
  expect(
    () => tree.blocks.add(probeBlock),
    throwsUnsupportedError,
    reason: reason,
  );
  int previousEnd = 0;
  for (final MdBlock block in tree.blocks) {
    expect(block.sourceRange.start >= previousEnd, isTrue, reason: reason);
    expect(
      lineStarts.contains(block.sourceRange.start),
      isTrue,
      reason: reason,
    );
    expect(lineEnds.contains(block.sourceRange.end), isTrue, reason: reason);
    previousEnd = block.sourceRange.end;
  }
  for (final MdNode node in _nodes(tree.blocks)) {
    final MdRange range = node.sourceRange;
    expect(_inside(range, whole), isTrue, reason: reason);
    expect(_inside(node.contentRange, range), isTrue, reason: reason);
    expect(
      () => node.markerRanges.add(empty),
      throwsUnsupportedError,
      reason: reason,
    );
    for (final MdRange marker in node.markerRanges) {
      expect(_inside(marker, range), isTrue, reason: reason);
    }
    for (final MdNode child in node.children) {
      expect(_inside(child.sourceRange, range), isTrue, reason: reason);
    }
    switch (node) {
      case MdBlock():
        expect(
          () => node.blocks.add(probeBlock),
          throwsUnsupportedError,
          reason: reason,
        );
        expect(
          () => node.inlines.add(probeInline),
          throwsUnsupportedError,
          reason: reason,
        );
        expect(node.kind, isNot(MdBlockKind.blankLine), reason: reason);
        _checkBlock(node, lines, reason);
      case MdInline():
        expect(
          () => node.children.add(probeInline),
          throwsUnsupportedError,
          reason: reason,
        );
    }
  }
}

void _checkBlock(MdBlock block, MdSourceLines lines, String reason) {
  final MdRange range = block.sourceRange;
  switch (block.kind) {
    case MdBlockKind.photoLine:
      final MdPhotoLineData data = block.data! as MdPhotoLineData;
      expect(block.contentRange, data.captionRange, reason: reason);
      expect(
        _merged(<MdRange>[block.contentRange, ...block.markerRanges]),
        range.isEmpty ? isEmpty : <MdRange>[range],
        reason: reason,
      );
    case MdBlockKind.thematicBreak:
      expect(block.markerRanges, <MdRange>[range], reason: reason);
    case MdBlockKind.fencedCode:
      final MdSourceLine first = lines.lines[lines.lineIndexAt(range.start)];
      expect(
        block.markerRanges.first,
        MdRange(range.start, first.end),
        reason: reason,
      );
    case MdBlockKind.table:
      expect(block.markerRanges, hasLength(1), reason: reason);
      final MdRange marker = block.markerRanges.single;
      final MdSourceLine line = lines.lines[lines.lineIndexAt(marker.start)];
      expect(marker, MdRange(line.start, line.end), reason: reason);
    default:
  }
}

int _listDepth(List<MdBlock> blocks) {
  int deepest = 0;
  for (final MdBlock block in blocks) {
    final int below = _listDepth(block.blocks);
    final int depth = block.kind == MdBlockKind.bulletList ? below + 1 : below;
    if (depth > deepest) {
      deepest = depth;
    }
  }
  return deepest;
}

void main() {
  test('every marker range listed in g4 is reported', () {
    expect(_markerList('  ## Harbour ##'), <String>['[0,5)', '[12,15)']);
    expect(_markerList('Low tide, **fog** lifted'), <String>[
      '[10,12)',
      '[15,17)',
    ]);
    final MdInline strong = parseNoteTree('Low tide, **fog** lifted')
        .blocks
        .single
        .inlines
        .firstWhere((MdInline inline) => inline.kind == MdInlineKind.strong);
    expect(strong.sourceRange, const MdRange(10, 17));
    expect(strong.contentRange, const MdRange(12, 15));
    const String styled = '*a* **b** ~~c~~ ==d==';
    expect(_markerList(styled), <String>[
      '[0,1)',
      '[2,3)',
      '[4,6)',
      '[7,9)',
      '[10,12)',
      '[13,15)',
      '[16,18)',
      '[19,21)',
    ]);
    expect(
      <MdInlineKind>[
        for (final MdInline inline in parseNoteTree(
          styled,
        ).blocks.single.inlines)
          if (inline.kind != MdInlineKind.text) inline.kind,
      ],
      <MdInlineKind>[
        MdInlineKind.emphasis,
        MdInlineKind.strong,
        MdInlineKind.strikethrough,
        MdInlineKind.highlight,
      ],
    );
    expect(_markerList('x ` a ` y'), <String>['[2,4)', '[5,7)']);
    const String link = '[sea](https://x.y "Sea")';
    expect(_markerList(link), <String>['[0,1)', '[4,24)']);
    final MdLinkData linkData =
        parseNoteTree(link).blocks.single.inlines.single.data! as MdLinkData;
    expect(linkData.destination, 'https://x.y');
    expect(linkData.title, 'Sea');
    expect(_markerList('see <https://x.y> now'), <String>['[4,5)', '[16,17)']);
    expect(_markerList(r'a\*b'), <String>['[1,2)']);
    expect(
      _markerList(
        r'a\'
        '\nb',
      ),
      <String>['[1,2)'],
    );
    expect(_markerList('a  \nb'), <String>['[1,3)']);
    expect(_markerList(' - a\n   b'), <String>['[0,3)', '[5,8)']);
    expect(_markerList('- a\n  - b'), <String>['[0,2)', '[4,8)']);
    expect(_markerList('- [x] a'), <String>['[0,6)']);
    expect(_markerList('> a\n>b\n> > c'), <String>['[0,2)', '[4,5)', '[7,11)']);
    expect(_markerList(' ```js\n  x\n ```'), <String>[
      '[0,6)',
      '[7,8)',
      '[11,15)',
    ]);
    expect(_markerList('  a\n   b'), <String>['[0,2)', '[4,7)']);
    expect(_markerList('| a | b |\n| - | - |\n| c | d |'), <String>[
      '[0,2)',
      '[3,6)',
      '[7,9)',
      '[10,19)',
      '[20,22)',
      '[23,26)',
      '[27,29)',
    ]);
    const String escapedPipe =
        r'| a \| b |'
        '\n| - |';
    expect(escapedPipe.length, 16);
    expect(_markerList(escapedPipe), <String>[
      '[0,2)',
      '[4,5)',
      '[8,10)',
      '[11,16)',
    ]);
    final MdBlock cell = parseNoteTree(
      escapedPipe,
    ).blocks.single.blocks.first.blocks.single;
    expect(cell.kind, MdBlockKind.tableCell);
    expect(cell.markerRanges, contains(const MdRange(4, 5)));
  });

  test('the fuzz corpus parses without throwing', () {
    for (int index = 0; index < noteFuzzCorpus.length; index++) {
      final String source = noteFuzzCorpus[index];
      for (final bool tables in <bool>[true, false]) {
        _checkWalk(
          source,
          tables,
          'corpus $index (tables: $tables): ${Uri.encodeComponent(source)}',
        );
      }
    }
  });

  test('the m9 old note shapes parse as the new grammar says', () {
    const String photoShape = 'photoLine';
    expect(_shape('- eggs\nThen we left.'), <String>[
      "bulletList(-)[listItem[paragraph[text 'eggs', softBreak, "
          "text 'Then we left.']]]",
    ]);
    expect(_shape('> "Quote"\n— Author'), <String>[
      "blockQuote[paragraph[text '\"Quote\"', softBreak, "
          "text '— Author']]",
    ]);
    expect(_shape('- a\n  detail'), <String>[
      "bulletList(-)[listItem[paragraph[text 'a', softBreak, text 'detail']]]",
    ]);
    const String nested =
        "bulletList(-)[listItem[paragraph[text 'a'], "
        "bulletList(-)[listItem[paragraph[text 'b']]]]]";
    expect(_shape('- a\n\t- b'), <String>[nested]);
    expect(_shape('- a\n    - b'), <String>[nested]);
    expect(_shape('- a\n$_photo'), <String>[
      "bulletList(-)[listItem[paragraph[text 'a']]]",
      photoShape,
    ]);
    expect(_shape('> q\n$_photo'), <String>[
      "blockQuote[paragraph[text 'q']]",
      photoShape,
    ]);
    expect(_shape('[label]()'), <String>["paragraph[link('')[text 'label']]"]);
    for (final (String, String) wrap in <(String, String)>[
      ('**', 'strong'),
      ('_', 'emphasis'),
      ('~~', 'strikethrough'),
    ]) {
      expect(_shape('${wrap.$1}line one\nline two${wrap.$1}'), <String>[
        "paragraph[${wrap.$2}[text 'line one', softBreak, text 'line two']]",
      ]);
    }
    expect(_shape('1. a\n1. b'), <String>[
      "orderedList(1, .)[listItem[paragraph[text 'a']], "
          "listItem[paragraph[text 'b']]]",
    ]);
    expect(_shape('Windows:\n14. doors'), <String>[
      "paragraph[text 'Windows:', softBreak, text '14. doors']",
    ]);
    expect(_shape('1. a\n2) b'), <String>[
      "orderedList(1, .)[listItem[paragraph[text 'a']]]",
      "orderedList(2, ))[listItem[paragraph[text 'b']]]",
    ]);
    const String shrug = '¯\\_(ツ)_/¯';
    expect(shrug.length, 9);
    expect(_shape(shrug), <String>[
      "paragraph[text '¯', escape '_', text '(ツ)_/¯']",
    ]);
    final MdInline escape = parseNoteTree(shrug).blocks.single.inlines
        .firstWhere((MdInline inline) => inline.kind == MdInlineKind.escape);
    expect(escape.sourceRange, const MdRange(1, 3));
    expect(escape.markerRanges, <MdRange>[const MdRange(1, 2)]);
    expect(plainTextOfTree(parseNoteTree(shrug), shrug), '¯_(ツ)_/¯');
    expect(_shape(r'\*not\*'), <String>[
      "paragraph[escape '*', text 'not', escape '*']",
    ]);
    expect(
      _shape(
        r'a\'
        '\nb',
      ),
      <String>["paragraph[text 'a', hardBreak, text 'b']"],
    );
    expect(_shape('***a***'), <String>[
      "paragraph[emphasis[strong[text 'a']]]",
    ]);
    expect(_shape('``a``'), <String>["paragraph[codeSpan 'a']"]);
    expect(_shape('# Title #'), <String>["heading(1)[text 'Title']"]);
    expect(_shape('#### Four\n##### Five\n###### Six'), <String>[
      "heading(4)[text 'Four']",
      "heading(5)[text 'Five']",
      "heading(6)[text 'Six']",
    ]);
    expect(_shape('a\n~~~\nb'), <String>[
      "paragraph[text 'a']",
      "fencedCode(not closed)[code 'b']",
    ]);
    final MdBlock fence = parseNoteTree('a\n~~~\nb').blocks.last;
    expect(fence.sourceRange, const MdRange(2, 7));
    expect(fence.markerRanges, <MdRange>[const MdRange(2, 5)]);
    expect(_shape('<https://x>'), <String>[
      "paragraph[autolink(uri, 'https://x')]",
    ]);
    expect(_shape('[a](b(c))'), <String>["paragraph[link('b(c)')[text 'a']]"]);
    expect(_shape('[a](u "t")'), <String>[
      "paragraph[link('u', 't')[text 'a']]",
    ]);
    expect(_shape('x==y=='), <String>[
      "paragraph[text 'x', highlight[text 'y']]",
    ]);
    expect(_shape('> > x'), <String>[
      "blockQuote[blockQuote[paragraph[text 'x']]]",
    ]);
    expect(_shape('> - x'), <String>[
      "blockQuote[bulletList(-)[listItem[paragraph[text 'x']]]]",
    ]);
    expect(_shape('> # x'), <String>["blockQuote[heading(1)[text 'x']]"]);
    expect(_shape('- [ ] x'), <String>[
      "bulletList(-)[listItem(unchecked)[paragraph[text 'x']]]",
    ]);
    expect(_shape('- a\n  $_photo'), <String>[
      "bulletList(-)[listItem[paragraph[text 'a', softBreak, text '!', "
          "link('photo/abc123abc123')[text 'p']]]]",
    ]);
  });

  test('empty and whitespace-only sources have no blocks', () {
    final MdTree empty = parseNoteTree('');
    expect(empty.blocks, isEmpty);
    expect(empty.sourceLength, 0);
    expect(parseNoteTree(' \n\t').blocks, isEmpty);
  });

  test('blank lines separate blocks and are never nodes', () {
    expect(_kinds('A\n\n\nB'), <String>['paragraph', 'paragraph']);
  });

  test('a crlf is one line break and a lone cr is content', () {
    expect(_shape('a\r\nb'), <String>[
      "paragraph[text 'a', softBreak, text 'b']",
    ]);
    expect(_shape('a\rb'), <String>["paragraph[text 'a\rb']"]);
  });

  test('the tables option passes through to the block parser', () {
    expect(_kinds('| a |\n| - |'), <String>['table']);
    expect(_kinds('| a |\n| - |', tables: false), <String>['paragraph']);
  });

  test('g2 block starts hold through the full parser', () {
    expect(_kinds('A\n$_photo'), <String>['paragraph', 'photoLine']);
    expect(_kinds('- a\n$_photo\n- b'), <String>[
      'bulletList',
      'photoLine',
      'bulletList',
    ]);
    expect(_kinds('> q\n$_photo'), <String>['blockQuote', 'photoLine']);
    final MdTree table = parseNoteTree('| a |\n| - |\n| b |\n$_photo');
    expect(
      <String>[for (final MdBlock block in table.blocks) block.kind.name],
      <String>['table', 'photoLine'],
    );
    expect(table.blocks.first.blocks, hasLength(2));
  });

  test('photo references of any hex form are photo lines outside code', () {
    expect(_kinds('![p](photo/ABC123ABC123)'), <String>['photoLine']);
    expect(_kinds('![a](photo/ab)'), <String>['photoLine']);
    final MdTree code = parseNoteTree('```\n$_photo\n```');
    expect(
      _nodes(code.blocks).whereType<MdBlock>().map((MdBlock b) => b.kind),
      isNot(contains(MdBlockKind.photoLine)),
    );
  });

  test('inline hosts carry inlines and code and photos carry none', () {
    final MdTree tree = parseNoteTree(
      '# a *b*\n\n| c |\n| - |\n| **d** |\n\n```\ne\n```\n$_photo',
    );
    final List<MdBlock> blocks = _nodes(
      tree.blocks,
    ).whereType<MdBlock>().toList();
    for (final MdBlock block in blocks) {
      switch (block.kind) {
        case MdBlockKind.heading || MdBlockKind.tableCell:
          expect(block.inlines, isNotEmpty);
        case MdBlockKind.fencedCode || MdBlockKind.photoLine:
          expect(block.inlines, isEmpty);
        default:
      }
    }
    expect(
      blocks.map((MdBlock b) => b.kind),
      containsAll(<MdBlockKind>[
        MdBlockKind.heading,
        MdBlockKind.tableCell,
        MdBlockKind.fencedCode,
        MdBlockKind.photoLine,
      ]),
    );
  });

  test('an escaped pipe inside a cell code span is a cell marker', () {
    const String source =
        r'| b `\|` az |'
        '\n| - |';
    final MdTree tree = parseNoteTree(source);
    final MdBlock cell = tree.blocks.single.blocks.first.blocks.single;
    final int backslash = source.indexOf(r'\');
    expect(cell.markerRanges, contains(MdRange(backslash, backslash + 1)));
    final MdInline code = cell.inlines.firstWhere(
      (MdInline inline) => inline.kind == MdInlineKind.codeSpan,
    );
    expect(_Shaper(source, tree).text(code.sourceRange), '|');
  });

  test('inline text inside a quote skips the quote markers', () {
    expect(_shape('> **a\n> b**'), <String>[
      "blockQuote[paragraph[strong[text 'a', softBreak, text 'b']]]",
    ]);
  });

  test('paragraph and container blank-line whitespace are markers', () {
    expect(_markerList('foo  '), <String>['[3,5)']);
    final MdTree list = parseNoteTree('- a\n  \n- b');
    expect(list.blocks.single.markerRanges, contains(const MdRange(4, 6)));
  });

  test('seven hashes make a paragraph', () {
    expect(_kinds('####### Seven'), <String>['paragraph']);
  });

  test('blockAt finds the top-level block holding an offset', () {
    const String source = 'A\n\n- b\n\n# c';
    final MdTree tree = parseNoteTree(source);
    expect(tree.blockAt(0)?.kind, MdBlockKind.paragraph);
    expect(tree.blockAt(4)?.kind, MdBlockKind.bulletList);
    expect(tree.blockAt(10)?.kind, MdBlockKind.heading);
    expect(tree.blockAt(2), isNull);
  });

  test('a list nested ten levels deep parses to depth ten', () {
    final String source = <String>[
      for (int level = 0; level < 10; level++) '${'  ' * level}- item $level',
    ].join('\n');
    expect(_listDepth(parseNoteTree(source).blocks), 10);
  });

  test('a long note and a long line parse without throwing', () {
    final StringBuffer buffer = StringBuffer();
    while (buffer.length < 100000) {
      buffer.write(noteFuzzCorpus.join('\n\n'));
      buffer.write('\n\n');
    }
    final String note = buffer.toString();
    expect(note.length, greaterThanOrEqualTo(100000));
    final MdTree tree = parseNoteTree(note);
    expect(tree.sourceLength, note.length);
    expect(() => plainTextOfTree(tree, note), returnsNormally);
    final String line = ('**fog** [sea](x) `c` \\* ' * 1300).substring(
      0,
      30000,
    );
    expect(line.length, 30000);
    final MdTree lineTree = parseNoteTree(line);
    expect(lineTree.blocks.single.kind, MdBlockKind.paragraph);
    expect(() => plainTextOfTree(lineTree, line), returnsNormally);
  });

  test('odd code units never throw', () {
    for (final String source in <String>[
      '\r',
      'a\u0000b',
      '\ud800x\udc00',
      '>' * 2000,
      '- ' * 2000,
      '[' * 5000,
    ]) {
      expect(() => _checkWalk(source, true, source), returnsNormally);
    }
  });
}
