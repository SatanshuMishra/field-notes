import 'package:field_notes/domain/notes/markdown/syntax_tree.dart';
import 'package:flutter_test/flutter_test.dart';

final Matcher _throwsAssertion = throwsA(isA<AssertionError>());

MdInline _text(int start, int end) => MdInline(
  kind: MdInlineKind.text,
  sourceRange: MdRange(start, end),
  contentRange: MdRange(start, end),
);

MdBlock _paragraph(int start, int end) => MdBlock(
  kind: MdBlockKind.paragraph,
  sourceRange: MdRange(start, end),
  contentRange: MdRange(start, end),
  inlines: <MdInline>[_text(start, end)],
);

MdInline _wrapped(MdInlineKind kind, int start, int end, int width) => MdInline(
  kind: kind,
  sourceRange: MdRange(start, end),
  contentRange: MdRange(start + width, end - width),
  markerRanges: <MdRange>[
    MdRange(start, start + width),
    MdRange(end - width, end),
  ],
  children: <MdInline>[_text(start + width, end - width)],
);

MdBlock _heading(int level) => MdBlock(
  kind: MdBlockKind.heading,
  sourceRange: MdRange(0, level + 5),
  contentRange: MdRange(level + 1, level + 5),
  markerRanges: <MdRange>[MdRange(0, level + 1)],
  inlines: <MdInline>[_text(level + 1, level + 5)],
  data: MdHeadingData(level),
);

MdBlock _item(int start, int end) => MdBlock(
  kind: MdBlockKind.listItem,
  sourceRange: MdRange(start, end),
  contentRange: MdRange(start + 2, end),
  markerRanges: <MdRange>[MdRange(start, start + 2)],
  blocks: <MdBlock>[_paragraph(start + 2, end)],
  data: const MdListItemData(taskState: MdTaskState.none),
);

MdBlock _bulletList(List<MdBlock> items, {required bool isTight}) => MdBlock(
  kind: MdBlockKind.bulletList,
  sourceRange: MdRange(
    items.first.sourceRange.start,
    items.last.sourceRange.end,
  ),
  contentRange: MdRange(
    items.first.sourceRange.start,
    items.last.sourceRange.end,
  ),
  blocks: items,
  data: MdBulletListData(bullet: '-', isTight: isTight),
);

MdBlock _taskItem(MdTaskState state) => MdBlock(
  kind: MdBlockKind.listItem,
  sourceRange: const MdRange(0, 7),
  contentRange: const MdRange(6, 7),
  markerRanges: const <MdRange>[MdRange(0, 2), MdRange(2, 5)],
  blocks: <MdBlock>[_paragraph(6, 7)],
  data: MdListItemData(taskState: state, taskBoxRange: const MdRange(2, 5)),
);

MdBlock _cell(int start, MdCellAlignment alignment) => MdBlock(
  kind: MdBlockKind.tableCell,
  sourceRange: MdRange(start, start + 3),
  contentRange: MdRange(start + 1, start + 2),
  markerRanges: <MdRange>[
    MdRange(start, start + 1),
    MdRange(start + 2, start + 3),
  ],
  inlines: <MdInline>[_text(start + 1, start + 2)],
  data: MdTableCellData(alignment: alignment),
);

MdBlock _table() => MdBlock(
  kind: MdBlockKind.table,
  sourceRange: const MdRange(0, 17),
  contentRange: const MdRange(0, 17),
  blocks: <MdBlock>[
    MdBlock(
      kind: MdBlockKind.tableRow,
      sourceRange: const MdRange(0, 17),
      contentRange: const MdRange(0, 17),
      markerRanges: const <MdRange>[
        MdRange(0, 1),
        MdRange(4, 5),
        MdRange(8, 9),
        MdRange(12, 13),
        MdRange(16, 17),
      ],
      blocks: <MdBlock>[
        _cell(1, MdCellAlignment.none),
        _cell(5, MdCellAlignment.left),
        _cell(9, MdCellAlignment.centre),
        _cell(13, MdCellAlignment.right),
      ],
    ),
  ],
);

MdPhotoLineData _photoData(int base) => MdPhotoLineData(
  reference: 'abc123abc123',
  referenceRange: MdRange(base + 18, base + 30),
  caption: 'Low tide',
  captionRange: MdRange(base + 2, base + 10),
  title: '',
  titleRange: MdRange(base + 32, base + 32),
);

MdBlock _photoLine(int base) => MdBlock(
  kind: MdBlockKind.photoLine,
  sourceRange: MdRange(base, base + 34),
  contentRange: MdRange(base + 2, base + 10),
  markerRanges: <MdRange>[
    MdRange(base, base + 2),
    MdRange(base + 10, base + 34),
  ],
  data: _photoData(base),
);

MdInline _link(int base) => MdInline(
  kind: MdInlineKind.link,
  sourceRange: MdRange(base, base + 17),
  contentRange: MdRange(base + 1, base + 2),
  markerRanges: <MdRange>[
    MdRange(base, base + 1),
    MdRange(base + 2, base + 17),
  ],
  children: <MdInline>[_text(base + 1, base + 2)],
  data: MdLinkData(
    destination: 'http://x',
    destinationRange: MdRange(base + 4, base + 12),
    title: 't',
    titleRange: MdRange(base + 14, base + 15),
  ),
);

MdInline _autolink(MdAutolinkKind kind, String target) => MdInline(
  kind: MdInlineKind.autolink,
  sourceRange: MdRange(0, target.length + 2),
  contentRange: MdRange(1, target.length + 1),
  markerRanges: <MdRange>[
    const MdRange(0, 1),
    MdRange(target.length + 1, target.length + 2),
  ],
  data: MdAutolinkData(kind: kind, target: target),
);

MdTree _fogTree({int closingMarkerEnd = 17}) {
  final MdInline strong = MdInline(
    kind: MdInlineKind.strong,
    sourceRange: const MdRange(10, 17),
    contentRange: const MdRange(12, 15),
    markerRanges: <MdRange>[
      const MdRange(10, 12),
      MdRange(15, closingMarkerEnd),
    ],
    children: <MdInline>[_text(12, 15)],
  );
  return MdTree(
    sourceLength: 24,
    blocks: <MdBlock>[
      MdBlock(
        kind: MdBlockKind.paragraph,
        sourceRange: const MdRange(0, 24),
        contentRange: const MdRange(0, 24),
        inlines: <MdInline>[_text(0, 10), strong, _text(17, 24)],
      ),
    ],
  );
}

MdBlock _shiftableQuote(int base) => MdBlock(
  kind: MdBlockKind.blockQuote,
  sourceRange: MdRange(base, base + 60),
  contentRange: MdRange(base + 2, base + 60),
  markerRanges: <MdRange>[MdRange(base, base + 2)],
  blocks: <MdBlock>[
    MdBlock(
      kind: MdBlockKind.bulletList,
      sourceRange: MdRange(base + 2, base + 9),
      contentRange: MdRange(base + 2, base + 9),
      blocks: <MdBlock>[
        MdBlock(
          kind: MdBlockKind.listItem,
          sourceRange: MdRange(base + 2, base + 9),
          contentRange: MdRange(base + 8, base + 9),
          markerRanges: <MdRange>[
            MdRange(base + 2, base + 4),
            MdRange(base + 4, base + 7),
          ],
          blocks: <MdBlock>[_paragraph(base + 8, base + 9)],
          data: MdListItemData(
            taskState: MdTaskState.checked,
            taskBoxRange: MdRange(base + 4, base + 7),
          ),
        ),
      ],
      data: const MdBulletListData(bullet: '*', isTight: true),
    ),
    MdBlock(
      kind: MdBlockKind.paragraph,
      sourceRange: MdRange(base + 10, base + 27),
      contentRange: MdRange(base + 10, base + 27),
      inlines: <MdInline>[_link(base + 10)],
    ),
  ],
);

void _expectFrozen<T>(List<T> list, T sample) {
  expect(() => list.add(sample), throwsUnsupportedError);
  expect(() => list.removeLast(), throwsUnsupportedError);
  expect(() => list[0] = sample, throwsUnsupportedError);
}

Iterable<MdNode> _walk(MdNode node) sync* {
  yield node;
  for (final MdNode child in node.children) {
    yield* _walk(child);
  }
}

Enum _kindOf(MdNode node) => switch (node) {
  MdBlock(:final MdBlockKind kind) => kind,
  MdInline(:final MdInlineKind kind) => kind,
};

void main() {
  test(
    'a strong node keeps its source range, content range and marker ranges',
    () {
      const String source = 'Low tide: **fog** lifted';
      final MdTree tree = _fogTree();
      final MdBlock paragraph = tree.blocks.single;
      final MdInline strong = paragraph.inlines[1];

      expect(source.length, 24);
      expect(strong.kind, MdInlineKind.strong);
      expect(strong.sourceRange, const MdRange(10, 17));
      expect(strong.contentRange, const MdRange(12, 15));
      expect(strong.markerRanges, <MdRange>[
        const MdRange(10, 12),
        const MdRange(15, 17),
      ]);
      expect(strong.contentRange.sliceOf(source), 'fog');
      for (final MdRange marker in strong.markerRanges) {
        expect(marker.sliceOf(source), '**');
      }
      expect(tree.blockAt(12), same(paragraph));
      expect(tree.blockAt(24), same(paragraph));
      expect(tree.blockIndexAt(12), 0);

      final MdTree twin = _fogTree();
      expect(identical(twin, tree), isFalse);
      expect(twin, tree);
      expect(twin.hashCode, tree.hashCode);
      expect(_fogTree(closingMarkerEnd: 16), isNot(tree));
    },
  );

  test('tree values expose no mutable lists', () {
    final List<MdRange> markers = <MdRange>[
      const MdRange(0, 2),
      const MdRange(5, 7),
    ];
    final List<MdInline> strongChildren = <MdInline>[_text(2, 5)];
    final MdInline strong = MdInline(
      kind: MdInlineKind.strong,
      sourceRange: const MdRange(0, 7),
      contentRange: const MdRange(2, 5),
      markerRanges: markers,
      children: strongChildren,
    );
    final List<MdInline> inlines = <MdInline>[strong];
    final MdBlock paragraph = MdBlock(
      kind: MdBlockKind.paragraph,
      sourceRange: const MdRange(0, 7),
      contentRange: const MdRange(0, 7),
      inlines: inlines,
    );
    final List<MdBlock> quoteBlocks = <MdBlock>[_paragraph(2, 5)];
    final List<MdRange> quoteMarkers = <MdRange>[const MdRange(0, 2)];
    final MdBlock quote = MdBlock(
      kind: MdBlockKind.blockQuote,
      sourceRange: const MdRange(0, 5),
      contentRange: const MdRange(2, 5),
      markerRanges: quoteMarkers,
      blocks: quoteBlocks,
    );
    final List<MdBlock> treeBlocks = <MdBlock>[paragraph];
    final MdTree tree = MdTree(sourceLength: 7, blocks: treeBlocks);

    markers.add(const MdRange(7, 7));
    strongChildren.clear();
    inlines.add(_text(7, 7));
    quoteBlocks.clear();
    quoteMarkers.clear();
    treeBlocks.add(_paragraph(7, 7));

    expect(strong.markerRanges, <MdRange>[
      const MdRange(0, 2),
      const MdRange(5, 7),
    ]);
    expect(strong.children, <MdInline>[_text(2, 5)]);
    expect(paragraph.inlines, <MdInline>[strong]);
    expect(quote.blocks, <MdBlock>[_paragraph(2, 5)]);
    expect(quote.markerRanges, <MdRange>[const MdRange(0, 2)]);
    expect(tree.blocks, <MdBlock>[paragraph]);

    final MdInline bare = _text(0, 1);
    final MdBlock bareParagraph = MdBlock(
      kind: MdBlockKind.paragraph,
      sourceRange: const MdRange(0, 1),
      contentRange: const MdRange(0, 1),
    );
    final MdTree emptyTree = MdTree(sourceLength: 0, blocks: <MdBlock>[]);
    const MdRange range = MdRange(0, 0);
    final MdInline inline = _text(0, 0);
    final MdBlock block = _paragraph(0, 0);

    _expectFrozen<MdRange>(strong.markerRanges, range);
    _expectFrozen<MdInline>(strong.children, inline);
    _expectFrozen<MdInline>(paragraph.inlines, inline);
    _expectFrozen<MdNode>(paragraph.children, inline);
    _expectFrozen<MdBlock>(paragraph.blocks, block);
    _expectFrozen<MdRange>(paragraph.markerRanges, range);
    _expectFrozen<MdBlock>(quote.blocks, block);
    _expectFrozen<MdNode>(quote.children, block);
    _expectFrozen<MdInline>(quote.inlines, inline);
    _expectFrozen<MdRange>(quote.markerRanges, range);
    _expectFrozen<MdBlock>(tree.blocks, block);
    _expectFrozen<MdRange>(bare.markerRanges, range);
    _expectFrozen<MdInline>(bare.children, inline);
    _expectFrozen<MdRange>(bareParagraph.markerRanges, range);
    _expectFrozen<MdInline>(bareParagraph.inlines, inline);
    _expectFrozen<MdBlock>(bareParagraph.blocks, block);
    _expectFrozen<MdBlock>(emptyTree.blocks, block);
  });

  test('every construct of g1 has a node kind', () {
    final Map<String, MdNode Function()> builders = <String, MdNode Function()>{
      for (int level = 1; level <= 6; level++)
        'ATX heading level $level': () => _heading(level),
      'thematic break': () => MdBlock(
        kind: MdBlockKind.thematicBreak,
        sourceRange: const MdRange(0, 3),
        contentRange: const MdRange(3, 3),
        markerRanges: const <MdRange>[MdRange(0, 3)],
      ),
      'fenced code with a backtick fence': () => MdBlock(
        kind: MdBlockKind.fencedCode,
        sourceRange: const MdRange(0, 13),
        contentRange: const MdRange(8, 9),
        markerRanges: const <MdRange>[MdRange(0, 7), MdRange(10, 13)],
        data: const MdFenceData(fence: '```', info: 'dart', isClosed: true),
      ),
      'fenced code with a tilde fence': () => MdBlock(
        kind: MdBlockKind.fencedCode,
        sourceRange: const MdRange(0, 5),
        contentRange: const MdRange(4, 5),
        markerRanges: const <MdRange>[MdRange(0, 3)],
        data: const MdFenceData(fence: '~~~', info: '', isClosed: false),
      ),
      'paragraph': () => _paragraph(0, 3),
      'blank line': () => MdBlock(
        kind: MdBlockKind.blankLine,
        sourceRange: const MdRange(0, 0),
        contentRange: const MdRange(0, 0),
      ),
      'block quote nested in a block quote': () => MdBlock(
        kind: MdBlockKind.blockQuote,
        sourceRange: const MdRange(0, 5),
        contentRange: const MdRange(2, 5),
        markerRanges: const <MdRange>[MdRange(0, 2)],
        blocks: <MdBlock>[
          MdBlock(
            kind: MdBlockKind.blockQuote,
            sourceRange: const MdRange(2, 5),
            contentRange: const MdRange(4, 5),
            markerRanges: const <MdRange>[MdRange(2, 4)],
            blocks: <MdBlock>[_paragraph(4, 5)],
          ),
        ],
      ),
      'bullet list': () => _bulletList(<MdBlock>[_item(0, 3)], isTight: true),
      'ordered list with start 3 and delimiter paren': () => MdBlock(
        kind: MdBlockKind.orderedList,
        sourceRange: const MdRange(0, 4),
        contentRange: const MdRange(0, 4),
        blocks: <MdBlock>[
          MdBlock(
            kind: MdBlockKind.listItem,
            sourceRange: const MdRange(0, 4),
            contentRange: const MdRange(3, 4),
            markerRanges: const <MdRange>[MdRange(0, 3)],
            blocks: <MdBlock>[_paragraph(3, 4)],
            data: const MdListItemData(taskState: MdTaskState.none),
          ),
        ],
        data: const MdOrderedListData(
          start: 3,
          delimiter: MdListDelimiter.paren,
          isTight: true,
        ),
      ),
      'tight list': () =>
          _bulletList(<MdBlock>[_item(0, 3), _item(4, 7)], isTight: true),
      'loose list': () =>
          _bulletList(<MdBlock>[_item(0, 3), _item(5, 8)], isTight: false),
      'list nested in a list item': () => _bulletList(<MdBlock>[
        MdBlock(
          kind: MdBlockKind.listItem,
          sourceRange: const MdRange(0, 9),
          contentRange: const MdRange(2, 9),
          markerRanges: const <MdRange>[MdRange(0, 2), MdRange(4, 6)],
          blocks: <MdBlock>[
            _paragraph(2, 3),
            _bulletList(<MdBlock>[_item(6, 9)], isTight: true),
          ],
          data: const MdListItemData(taskState: MdTaskState.none),
        ),
      ], isTight: true),
      'unchecked task item': () => _bulletList(<MdBlock>[
        _taskItem(MdTaskState.unchecked),
      ], isTight: true),
      'checked task item': () =>
          _bulletList(<MdBlock>[_taskItem(MdTaskState.checked)], isTight: true),
      'table with one cell of each alignment': _table,
      'backslash escape': () => MdInline(
        kind: MdInlineKind.escape,
        sourceRange: const MdRange(0, 2),
        contentRange: const MdRange(1, 2),
        markerRanges: const <MdRange>[MdRange(0, 1)],
      ),
      'code span': () => MdInline(
        kind: MdInlineKind.codeSpan,
        sourceRange: const MdRange(0, 3),
        contentRange: const MdRange(1, 2),
        markerRanges: const <MdRange>[MdRange(0, 1), MdRange(2, 3)],
      ),
      'emphasis': () => _wrapped(MdInlineKind.emphasis, 0, 3, 1),
      'strong': () => _wrapped(MdInlineKind.strong, 0, 5, 2),
      'strikethrough': () => _wrapped(MdInlineKind.strikethrough, 0, 5, 2),
      'highlight': () => _wrapped(MdInlineKind.highlight, 0, 5, 2),
      'inline link with a title': () => _link(0),
      'uri autolink': () =>
          _autolink(MdAutolinkKind.uri, 'https://example.com'),
      'email autolink': () => _autolink(MdAutolinkKind.email, 'a@b.co'),
      'hard break': () => MdInline(
        kind: MdInlineKind.hardBreak,
        sourceRange: const MdRange(1, 3),
        contentRange: const MdRange(2, 3),
        markerRanges: const <MdRange>[MdRange(1, 2)],
      ),
      'soft break': () => MdInline(
        kind: MdInlineKind.softBreak,
        sourceRange: const MdRange(1, 2),
        contentRange: const MdRange(1, 2),
      ),
      'photo line': () => _photoLine(0),
      'literal text': () => _text(0, 4),
    };

    final Set<Enum> kinds = <Enum>{};
    for (final MapEntry<String, MdNode Function()> entry in builders.entries) {
      expect(entry.value, returnsNormally, reason: entry.key);
      kinds.addAll(_walk(entry.value()).map(_kindOf));
    }

    expect(kinds, <Enum>{...MdBlockKind.values, ...MdInlineKind.values});
    expect(MdBlockKind.values.map((MdBlockKind k) => k.name).toList(), <String>[
      'heading',
      'thematicBreak',
      'fencedCode',
      'paragraph',
      'blankLine',
      'blockQuote',
      'bulletList',
      'orderedList',
      'listItem',
      'table',
      'tableRow',
      'tableCell',
      'photoLine',
    ]);
    expect(
      MdInlineKind.values.map((MdInlineKind k) => k.name).toList(),
      <String>[
        'text',
        'softBreak',
        'hardBreak',
        'codeSpan',
        'emphasis',
        'strong',
        'strikethrough',
        'highlight',
        'link',
        'autolink',
        'escape',
      ],
    );
  });

  group('MdRange', () {
    test('asserts a negative start and an end before its start', () {
      final int negative = -1;
      expect(() => MdRange(negative, 0), _throwsAssertion);
      expect(() => MdRange(negative + 5, 3), _throwsAssertion);
    });

    test('contains its start but not its end', () {
      const MdRange range = MdRange(10, 17);
      expect(range.contains(9), isFalse);
      expect(range.contains(10), isTrue);
      expect(range.contains(16), isTrue);
      expect(range.contains(17), isFalse);
      expect(const MdRange(4, 4).contains(4), isFalse);
      expect(range.length, 7);
      expect(range.isEmpty, isFalse);
      expect(const MdRange(4, 4).isEmpty, isTrue);
    });

    test('shifts, slices and prints', () {
      const MdRange range = MdRange(10, 17);
      expect(range.shifted(5), const MdRange(15, 22));
      expect(range.shifted(-10), const MdRange(0, 7));
      expect(() => range.shifted(-11), _throwsAssertion);
      expect(range.sliceOf('Low tide: **fog** lifted'), '**fog**');
      expect(range.toString(), 'MdRange(10, 17)');
    });

    test('slices a surrogate pair by its code units', () {
      const String source = 'a\u{1F30A}b';
      expect(source.length, 4);
      expect(const MdRange(1, 3).sliceOf(source), '\u{1F30A}');
    });
  });

  group('structural asserts', () {
    test('heading levels 0 and 7 assert', () {
      final List<int> levels = <int>[0, 7];
      for (final int level in levels) {
        expect(() => MdHeadingData(level), _throwsAssertion);
      }
    });

    test('a heading given blocks asserts', () {
      expect(
        () => MdBlock(
          kind: MdBlockKind.heading,
          sourceRange: const MdRange(0, 5),
          contentRange: const MdRange(2, 5),
          blocks: <MdBlock>[_paragraph(2, 5)],
          data: const MdHeadingData(1),
        ),
        _throwsAssertion,
      );
    });

    test('a paragraph given heading data asserts', () {
      expect(
        () => MdBlock(
          kind: MdBlockKind.paragraph,
          sourceRange: const MdRange(0, 3),
          contentRange: const MdRange(0, 3),
          data: const MdHeadingData(1),
        ),
        _throwsAssertion,
      );
    });

    test('a heading without data asserts', () {
      expect(
        () => MdBlock(
          kind: MdBlockKind.heading,
          sourceRange: const MdRange(0, 3),
          contentRange: const MdRange(2, 3),
        ),
        _throwsAssertion,
      );
    });

    test('a link without link data asserts', () {
      expect(
        () => MdInline(
          kind: MdInlineKind.link,
          sourceRange: const MdRange(0, 7),
          contentRange: const MdRange(1, 2),
          children: <MdInline>[_text(1, 2)],
        ),
        _throwsAssertion,
      );
    });

    test('text given autolink data asserts', () {
      expect(
        () => MdInline(
          kind: MdInlineKind.text,
          sourceRange: const MdRange(0, 3),
          contentRange: const MdRange(0, 3),
          data: const MdAutolinkData(kind: MdAutolinkKind.uri, target: 'x'),
        ),
        _throwsAssertion,
      );
    });

    test('text given children asserts', () {
      expect(
        () => MdInline(
          kind: MdInlineKind.text,
          sourceRange: const MdRange(0, 3),
          contentRange: const MdRange(0, 3),
          children: <MdInline>[_text(0, 3)],
        ),
        _throwsAssertion,
      );
    });

    test('overlapping or unsorted markers assert, touching ones do not', () {
      expect(
        () => MdInline(
          kind: MdInlineKind.codeSpan,
          sourceRange: const MdRange(0, 5),
          contentRange: const MdRange(2, 3),
          markerRanges: const <MdRange>[MdRange(0, 2), MdRange(1, 3)],
        ),
        _throwsAssertion,
      );
      expect(
        () => MdInline(
          kind: MdInlineKind.codeSpan,
          sourceRange: const MdRange(0, 5),
          contentRange: const MdRange(2, 3),
          markerRanges: const <MdRange>[MdRange(3, 5), MdRange(0, 2)],
        ),
        _throwsAssertion,
      );
      expect(
        () => MdInline(
          kind: MdInlineKind.codeSpan,
          sourceRange: const MdRange(0, 5),
          contentRange: const MdRange(2, 2),
          markerRanges: const <MdRange>[MdRange(0, 2), MdRange(2, 5)],
        ),
        returnsNormally,
      );
    });

    test('ranges outside the source range assert', () {
      expect(
        () => MdInline(
          kind: MdInlineKind.strong,
          sourceRange: const MdRange(0, 7),
          contentRange: const MdRange(2, 5),
          children: <MdInline>[_text(2, 8)],
        ),
        _throwsAssertion,
      );
      expect(
        () => MdInline(
          kind: MdInlineKind.text,
          sourceRange: const MdRange(2, 5),
          contentRange: const MdRange(1, 5),
        ),
        _throwsAssertion,
      );
      expect(
        () => MdInline(
          kind: MdInlineKind.codeSpan,
          sourceRange: const MdRange(2, 5),
          contentRange: const MdRange(3, 4),
          markerRanges: const <MdRange>[MdRange(4, 6)],
        ),
        _throwsAssertion,
      );
      expect(
        () => MdBlock(
          kind: MdBlockKind.blockQuote,
          sourceRange: const MdRange(0, 4),
          contentRange: const MdRange(2, 4),
          blocks: <MdBlock>[_paragraph(2, 5)],
        ),
        _throwsAssertion,
      );
    });

    test('empty ranges at either end of the parent lie inside it', () {
      expect(
        () => MdBlock(
          kind: MdBlockKind.heading,
          sourceRange: const MdRange(0, 2),
          contentRange: const MdRange(2, 2),
          markerRanges: const <MdRange>[MdRange(0, 2)],
          inlines: <MdInline>[_text(2, 2)],
          data: const MdHeadingData(1),
        ),
        returnsNormally,
      );
      expect(
        () => MdBlock(
          kind: MdBlockKind.paragraph,
          sourceRange: const MdRange(0, 2),
          contentRange: const MdRange(0, 0),
          inlines: <MdInline>[_text(0, 0)],
        ),
        returnsNormally,
      );
    });

    test('overlapping or unsorted children assert, gaps do not', () {
      expect(
        () => MdBlock(
          kind: MdBlockKind.paragraph,
          sourceRange: const MdRange(0, 9),
          contentRange: const MdRange(0, 9),
          inlines: <MdInline>[_text(0, 4), _text(3, 9)],
        ),
        _throwsAssertion,
      );
      expect(
        () => MdBlock(
          kind: MdBlockKind.blockQuote,
          sourceRange: const MdRange(0, 9),
          contentRange: const MdRange(2, 9),
          blocks: <MdBlock>[_paragraph(6, 9), _paragraph(2, 4)],
        ),
        _throwsAssertion,
      );
      expect(
        () => MdBlock(
          kind: MdBlockKind.blockQuote,
          sourceRange: const MdRange(0, 9),
          contentRange: const MdRange(2, 9),
          blocks: <MdBlock>[_paragraph(2, 4), _paragraph(6, 9)],
        ),
        returnsNormally,
      );
    });

    test('a paragraph given blocks and a quote given inlines assert', () {
      expect(
        () => MdBlock(
          kind: MdBlockKind.paragraph,
          sourceRange: const MdRange(0, 3),
          contentRange: const MdRange(0, 3),
          blocks: <MdBlock>[_paragraph(0, 3)],
        ),
        _throwsAssertion,
      );
      expect(
        () => MdBlock(
          kind: MdBlockKind.blockQuote,
          sourceRange: const MdRange(0, 3),
          contentRange: const MdRange(2, 3),
          inlines: <MdInline>[_text(2, 3)],
        ),
        _throwsAssertion,
      );
      expect(
        () => MdBlock(
          kind: MdBlockKind.fencedCode,
          sourceRange: const MdRange(0, 5),
          contentRange: const MdRange(4, 5),
          inlines: <MdInline>[_text(4, 5)],
          data: const MdFenceData(fence: '```', info: '', isClosed: false),
        ),
        _throwsAssertion,
      );
    });

    test('a bullet list holding a paragraph asserts', () {
      expect(
        () => MdBlock(
          kind: MdBlockKind.bulletList,
          sourceRange: const MdRange(0, 3),
          contentRange: const MdRange(0, 3),
          blocks: <MdBlock>[_paragraph(0, 3)],
          data: const MdBulletListData(bullet: '-', isTight: true),
        ),
        _throwsAssertion,
      );
    });

    test('a table holding a table cell directly asserts', () {
      expect(
        () => MdBlock(
          kind: MdBlockKind.table,
          sourceRange: const MdRange(0, 5),
          contentRange: const MdRange(0, 5),
          blocks: <MdBlock>[_cell(1, MdCellAlignment.none)],
        ),
        _throwsAssertion,
      );
    });

    test('a table row holding a paragraph asserts', () {
      expect(
        () => MdBlock(
          kind: MdBlockKind.tableRow,
          sourceRange: const MdRange(0, 5),
          contentRange: const MdRange(0, 5),
          blocks: <MdBlock>[_paragraph(1, 4)],
        ),
        _throwsAssertion,
      );
    });

    test('a task box that is not one of the item markers asserts', () {
      expect(
        () => MdBlock(
          kind: MdBlockKind.listItem,
          sourceRange: const MdRange(0, 7),
          contentRange: const MdRange(6, 7),
          markerRanges: const <MdRange>[MdRange(0, 2)],
          blocks: <MdBlock>[_paragraph(6, 7)],
          data: const MdListItemData(
            taskState: MdTaskState.checked,
            taskBoxRange: MdRange(2, 5),
          ),
        ),
        _throwsAssertion,
      );
    });

    test('unsorted, overlapping or overlong top-level blocks assert', () {
      expect(
        () => MdTree(
          sourceLength: 9,
          blocks: <MdBlock>[_paragraph(5, 9), _paragraph(0, 3)],
        ),
        _throwsAssertion,
      );
      expect(
        () => MdTree(
          sourceLength: 9,
          blocks: <MdBlock>[_paragraph(0, 5), _paragraph(4, 9)],
        ),
        _throwsAssertion,
      );
      expect(
        () => MdTree(sourceLength: 8, blocks: <MdBlock>[_paragraph(0, 9)]),
        _throwsAssertion,
      );
      final int negative = -1;
      expect(
        () => MdTree(sourceLength: negative, blocks: <MdBlock>[]),
        _throwsAssertion,
      );
    });

    test('a box range with state none, or a task without one, asserts', () {
      MdListItemData item(MdTaskState state, MdRange? box) =>
          MdListItemData(taskState: state, taskBoxRange: box);
      expect(
        () => item(MdTaskState.none, const MdRange(2, 5)),
        _throwsAssertion,
      );
      expect(() => item(MdTaskState.checked, null), _throwsAssertion);
      expect(() => item(MdTaskState.none, null), returnsNormally);
    });

    test('a photo line or link with a title but no title range asserts', () {
      const String title = 'left small';
      expect(
        () => MdPhotoLineData(
          reference: 'abc123abc123',
          referenceRange: const MdRange(18, 30),
          caption: 'Low tide',
          captionRange: const MdRange(2, 10),
          title: title,
          titleRange: null,
        ),
        _throwsAssertion,
      );
      expect(
        () => MdLinkData(
          destination: 'http://x',
          destinationRange: const MdRange(4, 12),
          title: title,
        ),
        _throwsAssertion,
      );
    });

    test('bullets and ordered starts outside their sets assert', () {
      MdBulletListData bulletList(String bullet) =>
          MdBulletListData(bullet: bullet, isTight: true);
      expect(() => bulletList('='), _throwsAssertion);
      expect(() => bulletList('*'), returnsNormally);
      final List<int> starts = <int>[-1, 1000000000];
      for (final int start in starts) {
        expect(
          () => MdOrderedListData(
            start: start,
            delimiter: MdListDelimiter.period,
            isTight: true,
          ),
          _throwsAssertion,
        );
      }
    });
  });

  test('a photo line with an empty title holds an empty title range', () {
    const String source = '![Low tide](photo/abc123abc123 "")';
    expect(source.length, 34);
    final MdPhotoLineData data = _photoData(0);
    expect(data.title, '');
    expect(data.titleRange, const MdRange(32, 32));
    expect(data.referenceRange.sliceOf(source), data.reference);
    expect(data.captionRange.sliceOf(source), data.caption);
    expect(() => _photoLine(0), returnsNormally);
  });

  group('blockAt', () {
    final MdTree twoBreaks = MdTree(
      sourceLength: 4,
      blocks: <MdBlock>[_paragraph(0, 1), _paragraph(3, 4)],
    );

    test('finds a block at its start and at its inclusive end', () {
      expect(twoBreaks.blockAt(0), twoBreaks.blocks[0]);
      expect(twoBreaks.blockAt(1), twoBreaks.blocks[0]);
      expect(twoBreaks.blockIndexAt(3), 1);
      expect(twoBreaks.blockIndexAt(4), 1);
    });

    test('is null strictly inside a separator of two line breaks', () {
      expect(twoBreaks.blockAt(2), isNull);
      expect(twoBreaks.blockIndexAt(2), isNull);
    });

    test('is null between the CR and the LF of a CRLF separator', () {
      const String source = 'a\r\nb';
      final MdTree tree = MdTree(
        sourceLength: source.length,
        blocks: <MdBlock>[_paragraph(0, 1), _paragraph(3, 4)],
      );
      expect(tree.blockAt(1), tree.blocks[0]);
      expect(tree.blockAt(2), isNull);
      expect(tree.blockAt(3), tree.blocks[1]);
    });

    test(
      'is null on a blank line before the first or after the last block',
      () {
        final MdTree tree = MdTree(
          sourceLength: 5,
          blocks: <MdBlock>[_paragraph(1, 2)],
        );
        expect(tree.blockAt(0), isNull);
        expect(tree.blockAt(1), tree.blocks[0]);
        expect(tree.blockAt(2), tree.blocks[0]);
        expect(tree.blockAt(4), isNull);
        expect(tree.blockAt(5), isNull);
      },
    );

    test('is null on an empty tree', () {
      expect(MdTree(sourceLength: 0, blocks: <MdBlock>[]).blockAt(0), isNull);
      final MdTree blank = MdTree(sourceLength: 3, blocks: <MdBlock>[]);
      expect(blank.blockAt(2), isNull);
      expect(blank.blockIndexAt(3), isNull);
    });

    test('gives a touching boundary to the later block', () {
      final MdTree tree = MdTree(
        sourceLength: 6,
        blocks: <MdBlock>[_paragraph(0, 3), _paragraph(3, 6)],
      );
      expect(tree.blockIndexAt(2), 0);
      expect(tree.blockIndexAt(3), 1);
      expect(tree.blockAt(3), tree.blocks[1]);
    });

    test('finds every block of a long tree by binary search', () {
      final List<MdBlock> blocks = <MdBlock>[
        for (int i = 0; i < 400; i++) _paragraph(i * 5, i * 5 + 3),
      ];
      final MdTree tree = MdTree(sourceLength: 2000, blocks: blocks);
      for (int offset = 0; offset <= 2000; offset++) {
        final int index = offset ~/ 5;
        final int expected = offset % 5 <= 3 && index < 400 ? index : -1;
        expect(tree.blockIndexAt(offset) ?? -1, expected, reason: '$offset');
      }
    });

    test('throws a range error outside the source', () {
      expect(() => twoBreaks.blockAt(-1), throwsRangeError);
      expect(() => twoBreaks.blockAt(5), throwsRangeError);
      expect(() => twoBreaks.blockIndexAt(-1), throwsRangeError);
      expect(() => twoBreaks.blockIndexAt(5), throwsRangeError);
    });
  });

  group('shifted', () {
    test(
      'a deep shifted tree equals the tree built at the shifted offsets',
      () {
        for (final int delta in <int>[0, 1, 7, 1000]) {
          final MdBlock shifted = _shiftableQuote(3).shifted(delta);
          final MdBlock built = _shiftableQuote(3 + delta);
          expect(shifted, built);
          expect(shifted.hashCode, built.hashCode);
          expect(
            MdTree(sourceLength: 70 + delta, blocks: <MdBlock>[shifted]),
            MdTree(sourceLength: 70 + delta, blocks: <MdBlock>[built]),
          );
        }
        expect(_shiftableQuote(10).shifted(-10), _shiftableQuote(0));
        expect(_photoLine(0).shifted(5), _photoLine(5));
        expect(_photoData(0).shifted(5), _photoData(5));
      },
    );

    test('shifting below zero asserts', () {
      expect(() => _shiftableQuote(3).shifted(-4), _throwsAssertion);
      expect(() => _link(2).shifted(-3), _throwsAssertion);
    });

    test('data ranges move with the node', () {
      final MdLinkData link = _link(0).shifted(4).data! as MdLinkData;
      expect(link.destinationRange, const MdRange(8, 16));
      expect(link.titleRange, const MdRange(18, 19));
      const MdListItemData item = MdListItemData(
        taskState: MdTaskState.unchecked,
        taskBoxRange: MdRange(2, 5),
      );
      expect(
        item.shifted(3),
        const MdListItemData(
          taskState: MdTaskState.unchecked,
          taskBoxRange: MdRange(5, 8),
        ),
      );
      expect(const MdHeadingData(2).shifted(9), const MdHeadingData(2));
    });
  });

  test('canResolve accepts only 12 to 64 lower-case hex digits', () {
    MdPhotoLineData photo(String reference) => MdPhotoLineData(
      reference: reference,
      referenceRange: MdRange(18, 18 + reference.length),
      caption: '',
      captionRange: const MdRange(2, 2),
      title: null,
      titleRange: null,
    );
    expect(photo('abc123abc123').canResolve, isTrue);
    expect(photo('ABC123ABC123').canResolve, isFalse);
    expect(photo('abc12').canResolve, isFalse);
    expect(photo('abc123abc12').canResolve, isFalse);
    expect(photo('abc123abc12g').canResolve, isFalse);
    expect(photo('0123456789abcdef' * 4).canResolve, isTrue);
    expect(photo('${'0123456789abcdef' * 4}0').canResolve, isFalse);
  });

  group('data classes compare by value', () {
    void expectValue(Object a, Object twin, Object other) {
      expect(a, twin);
      expect(a.hashCode, twin.hashCode);
      expect(a, isNot(other));
    }

    test('block data', () {
      expectValue(
        MdHeadingData(int.parse('2')),
        const MdHeadingData(2),
        const MdHeadingData(3),
      );
      expectValue(
        MdFenceData(fence: '`' * 3, info: 'dart', isClosed: true),
        const MdFenceData(fence: '```', info: 'dart', isClosed: true),
        const MdFenceData(fence: '```', info: 'dart', isClosed: false),
      );
      expectValue(
        MdBulletListData(bullet: '-'.substring(0), isTight: true),
        const MdBulletListData(bullet: '-', isTight: true),
        const MdBulletListData(bullet: '+', isTight: true),
      );
      expectValue(
        MdOrderedListData(
          start: int.parse('3'),
          delimiter: MdListDelimiter.paren,
          isTight: false,
        ),
        const MdOrderedListData(
          start: 3,
          delimiter: MdListDelimiter.paren,
          isTight: false,
        ),
        const MdOrderedListData(
          start: 3,
          delimiter: MdListDelimiter.period,
          isTight: false,
        ),
      );
      expectValue(
        MdListItemData(
          taskState: MdTaskState.checked,
          taskBoxRange: MdRange(int.parse('2'), 5),
        ),
        const MdListItemData(
          taskState: MdTaskState.checked,
          taskBoxRange: MdRange(2, 5),
        ),
        const MdListItemData(
          taskState: MdTaskState.unchecked,
          taskBoxRange: MdRange(2, 5),
        ),
      );
      expectValue(
        MdTableCellData(alignment: MdCellAlignment.values[2]),
        const MdTableCellData(alignment: MdCellAlignment.centre),
        const MdTableCellData(alignment: MdCellAlignment.right),
      );
      expectValue(_photoData(0), _photoData(0), _photoData(1));
    });

    test('inline data', () {
      expectValue(_link(0).data!, _link(0).data!, _link(1).data!);
      expectValue(
        MdAutolinkData(kind: MdAutolinkKind.email, target: 'a@b.co'),
        const MdAutolinkData(kind: MdAutolinkKind.email, target: 'a@b.co'),
        const MdAutolinkData(kind: MdAutolinkKind.uri, target: 'a@b.co'),
      );
    });

    test('nodes print their kind, ranges and children', () {
      final String printed = _fogTree().toString();
      expect(printed, contains('strong MdRange(10, 17)'));
      expect(printed, contains('MdRange(15, 17)'));
      expect(printed, contains('paragraph MdRange(0, 24)'));
    });
  });
}
