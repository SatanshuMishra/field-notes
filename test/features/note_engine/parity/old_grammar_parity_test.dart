import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/domain/notes/note_plain_text.dart';

import '../../../domain/notes/note_fuzz_corpus.dart';

MdBlock _single(String source) => parseNoteTree(source).blocks.single;

List<MdBlockKind> _kinds(String source) => <MdBlockKind>[
  for (final MdBlock block in parseNoteTree(source).blocks) block.kind,
];

String _content(MdNode node, String source) =>
    node.contentRange.sliceOf(source);

Iterable<MdNode> _nodes(List<MdNode> nodes) sync* {
  for (final MdNode node in nodes) {
    yield node;
    yield* _nodes(node.children);
  }
}

Iterable<MdNode> _treeNodes(MdTree tree) => _nodes(tree.blocks);

Iterable<MdInline> _inlines(String source) =>
    _treeNodes(parseNoteTree(source)).whereType<MdInline>();

bool _hasInline(String source, MdInlineKind kind) =>
    _inlines(source).any((MdInline inline) => inline.kind == kind);

List<MdInlineKind> _inlineKinds(List<MdInline> inlines) => <MdInlineKind>[
  for (final MdInline inline in inlines) inline.kind,
];

MdBlock _paragraphOf(MdBlock item) => item.blocks.single;

bool _inside(MdRange inner, MdRange outer) =>
    outer.start <= inner.start && inner.end <= outer.end;

bool _overlaps(MdRange a, MdRange b) => a.start < b.end && b.start < a.end;

void _expectOrdered(List<MdRange> ranges, String reason) {
  for (int i = 1; i < ranges.length; i++) {
    expect(
      ranges[i].start,
      greaterThanOrEqualTo(ranges[i - 1].end),
      reason: '$reason ${ranges[i - 1]} then ${ranges[i]}',
    );
  }
}

bool _isSeparator(int unit) =>
    unit == 0x0D || unit == 0x0A || unit == 0x20 || unit == 0x09;

void _checkTopLevelTiling() {
  for (final (int index, String source) in noteFuzzCorpus.indexed) {
    final String reason = 'corpus #$index';
    final MdTree tree = parseNoteTree(source, tables: true);
    final List<MdRange> ranges = <MdRange>[
      for (final MdBlock block in tree.blocks) block.sourceRange,
    ];
    _expectOrdered(ranges, reason);
    for (final MdRange range in ranges) {
      expect(range.end, lessThanOrEqualTo(source.length), reason: reason);
    }
    for (int at = 0; at < source.length; at++) {
      if (ranges.any((MdRange range) => range.contains(at))) {
        continue;
      }
      expect(
        _isSeparator(source.codeUnitAt(at)),
        isTrue,
        reason: '$reason unit $at',
      );
    }
    expect(
      _treeNodes(tree).whereType<MdBlock>().where(
        (MdBlock block) => block.kind == MdBlockKind.blankLine,
      ),
      isEmpty,
      reason: reason,
    );
  }
}

void _checkMemoReplacedByDeterminism() {
  for (final (int index, String source) in noteFuzzCorpus.indexed) {
    final MdTree tree = parseNoteTree(source);
    final MdTree copy = parseNoteTree(String.fromCharCodes(source.codeUnits));
    expect(copy, tree, reason: 'corpus #$index');
    expect(copy.hashCode, tree.hashCode, reason: 'corpus #$index');
  }
}

void main() {
  group('note_parser_test.dart', () {
    test('empty source yields no blocks', () {
      final MdTree tree = parseNoteTree('');
      expect(tree.blocks, isEmpty);
      expect(tree.sourceLength, 0);
    });

    test('a whitespace-only source yields one empty paragraph', () {
      expect(parseNoteTree('\n \n').blocks, isEmpty);
      expect(plainTextOf('\n \n'), '');
    });

    test('plain lines form one paragraph with a soft break', () {
      final MdBlock block = _single('one\ntwo');
      expect(block.kind, MdBlockKind.paragraph);
      expect(_inlineKinds(block.inlines), <MdInlineKind>[
        MdInlineKind.text,
        MdInlineKind.softBreak,
        MdInlineKind.text,
      ]);
      expect(
        <MdRange>[
          for (final MdInline inline in block.inlines) inline.sourceRange,
        ],
        const <MdRange>[MdRange(0, 3), MdRange(3, 4), MdRange(4, 7)],
      );
      expect(plainTextOf('one\ntwo'), 'one\ntwo');
    });

    test('a blank line separates paragraphs', () {
      final List<MdBlock> blocks = parseNoteTree('one\n\ntwo').blocks;
      expect(_kinds('one\n\ntwo'), <MdBlockKind>[
        MdBlockKind.paragraph,
        MdBlockKind.paragraph,
      ]);
      expect(blocks[0].sourceRange, const MdRange(0, 3));
      expect(blocks[1].sourceRange, const MdRange(5, 8));
    });

    test('headings run from one to three hashes followed by a space', () {
      for (int level = 1; level <= 6; level++) {
        final String source = '${'#' * level} Title';
        final MdBlock block = _single(source);
        expect(block.kind, MdBlockKind.heading, reason: source);
        expect(block.data, MdHeadingData(level), reason: source);
        expect(_content(block, source), 'Title', reason: source);
        expect(block.markerRanges.first, MdRange(0, level + 1), reason: source);
      }
    });

    test('four hashes and a hashtag are paragraphs', () {
      final MdBlock deep = _single('#### deep');
      expect(deep.kind, MdBlockKind.heading);
      expect(deep.data, const MdHeadingData(4));
      expect(_content(deep, '#### deep'), 'deep');
      expect(_single('#hashtag').kind, MdBlockKind.paragraph);
      expect(plainTextOf('#hashtag'), '#hashtag');
    });

    test('a bare hash is an empty heading', () {
      final MdBlock block = _single('#');
      expect(block.kind, MdBlockKind.heading);
      expect(block.data, const MdHeadingData(1));
      expect(block.contentRange.isEmpty, isTrue);
      expect(plainTextOf('#'), '');
    });

    test('bullets accept dash, star and plus markers', () {
      for (final String marker in <String>['-', '*', '+']) {
        final String source = '$marker milk';
        final MdBlock list = _single(source);
        expect(list.kind, MdBlockKind.bulletList, reason: source);
        expect((list.data! as MdBulletListData).bullet, marker, reason: source);
        final MdBlock item = list.blocks.single;
        expect(item.kind, MdBlockKind.listItem, reason: source);
        expect(item.markerRanges.first, const MdRange(0, 2), reason: source);
        expect(_content(_paragraphOf(item), source), 'milk', reason: source);
      }
    });

    test('a marker without a following space is a paragraph', () {
      expect(_single('-milk').kind, MdBlockKind.paragraph);
      expect(_single('1.milk').kind, MdBlockKind.paragraph);
    });

    test('numbered items keep the typed ordinal', () {
      const String source = '12) eggs';
      final MdBlock list = _single(source);
      expect(list.kind, MdBlockKind.orderedList);
      final MdOrderedListData data = list.data! as MdOrderedListData;
      expect(data.start, 12);
      expect(data.delimiter, MdListDelimiter.paren);
      final MdBlock item = list.blocks.single;
      expect(item.markerRanges.first, const MdRange(0, 4));
      expect(_content(_paragraphOf(item), source), 'eggs');
    });

    test('consecutive list lines are separate blocks', () {
      const String source = '- a\n- b\n1. c';
      final List<MdBlock> blocks = parseNoteTree(source).blocks;
      expect(_kinds(source), <MdBlockKind>[
        MdBlockKind.bulletList,
        MdBlockKind.orderedList,
      ]);
      expect(
        <String>[
          for (final MdBlock item in blocks[0].blocks)
            _content(_paragraphOf(item), source),
        ],
        <String>['a', 'b'],
      );
      expect(
        <String>[
          for (final MdBlock item in blocks[1].blocks)
            _content(_paragraphOf(item), source),
        ],
        <String>['c'],
      );
    });

    test('consecutive quote lines merge into one quote', () {
      final MdBlock quote = _single('> one\n> two');
      expect(quote.kind, MdBlockKind.blockQuote);
      expect(quote.markerRanges, const <MdRange>[MdRange(0, 2), MdRange(6, 8)]);
      expect(quote.blocks.single.kind, MdBlockKind.paragraph);
      expect(plainTextOf('> one\n> two'), 'one\ntwo');
    });

    test('a plain line after a quote starts a paragraph', () {
      const String source = '> one\ntwo';
      final MdBlock quote = _single(source);
      expect(quote.kind, MdBlockKind.blockQuote);
      final List<MdInline> inlines = quote.blocks.single.inlines;
      expect(_inlineKinds(inlines), <MdInlineKind>[
        MdInlineKind.text,
        MdInlineKind.softBreak,
        MdInlineKind.text,
      ]);
      expect(inlines[0].sourceRange.sliceOf(source), 'one');
      expect(inlines[2].sourceRange.sliceOf(source), 'two');
    });

    test('a fenced code block keeps raw content and a language', () {
      const String source = '```dart\n# raw\n- raw\n```';
      final MdBlock block = _single(source);
      expect(block.kind, MdBlockKind.fencedCode);
      expect(
        block.data,
        const MdFenceData(fence: '```', info: 'dart', isClosed: true),
      );
      expect(block.contentRange, const MdRange(8, 19));
      expect(_content(block, source), '# raw\n- raw');
      expect(block.markerRanges, const <MdRange>[
        MdRange(0, 7),
        MdRange(20, 23),
      ]);
    });

    test('an unclosed fence runs to the end of the note', () {
      final MdBlock block = _single('```\ncode\n\n');
      expect(block.kind, MdBlockKind.fencedCode);
      expect(block.sourceRange, const MdRange(0, 10));
      expect((block.data! as MdFenceData).isClosed, isFalse);
      expect(block.markerRanges.first, const MdRange(0, 3));
      expect(plainTextOf('```\ncode\n\n'), 'code');
    });

    test('a closing fence must be at least as long as the opener', () {
      const String source = '````\n```\n````';
      final MdBlock block = _single(source);
      expect(block.kind, MdBlockKind.fencedCode);
      expect(_content(block, source), '```');
      expect((block.data! as MdFenceData).isClosed, isTrue);
    });

    test('dividers accept dashes, stars and underscores with spaces', () {
      for (final String line in <String>[
        '---',
        '***',
        '___',
        '- - -',
        '----',
      ]) {
        expect(_single(line).kind, MdBlockKind.thematicBreak, reason: line);
        expect(plainTextOf(line), '', reason: line);
      }
      expect(_single('--').kind, MdBlockKind.paragraph);
    });

    test('a photo line parses alt, reference and attributes', () {
      const String source = '![a walk](photo/0123456789ab "right medium")';
      final MdBlock block = _single(source);
      expect(block.kind, MdBlockKind.photoLine);
      expect(block.sourceRange, const MdRange(0, 44));
      expect(block.markerRanges, const <MdRange>[
        MdRange(0, 2),
        MdRange(8, 44),
      ]);
      final MdPhotoLineData data = block.data! as MdPhotoLineData;
      expect(data.caption, 'a walk');
      expect(data.captionRange, const MdRange(2, 8));
      expect(data.reference, '0123456789ab');
      expect(data.referenceRange, const MdRange(16, 28));
      expect(data.title, 'right medium');
      expect(data.titleRange, const MdRange(30, 42));
      expect(data.canResolve, isTrue);
      final MdPhotoPlacement placement = MdPhotoLine.ofBlock(
        block,
        source,
      ).placement;
      expect(placement.isValid, isTrue);
      expect(placement.side, MdPhotoSide.right);
      expect(placement.size, MdPhotoSize.medium);
      expect(plainTextOf(source), 'a walk');
    });

    test('a photo line without attributes has an empty attribute slot', () {
      const String source = '![](photo/ab)';
      final MdBlock block = _single(source);
      expect(block.kind, MdBlockKind.photoLine);
      expect(block.markerRanges, const <MdRange>[
        MdRange(0, 2),
        MdRange(2, 13),
      ]);
      final MdPhotoLineData data = block.data! as MdPhotoLineData;
      expect(data.caption, '');
      expect(data.title, isNull);
      expect(data.titleRange, isNull);
      expect(data.reference, 'ab');
      expect(data.canResolve, isFalse);
      final MdPhotoPlacement placement = MdPhotoLine.ofBlock(
        block,
        source,
      ).placement;
      expect(placement.isValid, isTrue);
      expect(placement, const MdPhotoPlacement());
    });

    test('an image that is not a photo reference stays prose', () {
      const String source = '![a](http://x)';
      final MdBlock block = _single(source);
      expect(block.kind, MdBlockKind.paragraph);
      expect(_inlineKinds(block.inlines), <MdInlineKind>[
        MdInlineKind.text,
        MdInlineKind.link,
      ]);
      expect(block.inlines[0].sourceRange.sliceOf(source), '!');
      final MdInline link = block.inlines[1];
      expect((link.data! as MdLinkData).destination, 'http://x');
      expect(_content(link, source), 'a');
      expect(_single('![a](photo/ab) trailing').kind, MdBlockKind.paragraph);
      expect(_single('![a](photo/)').kind, MdBlockKind.paragraph);
    });

    test('a marker line ends the paragraph before it', () {
      expect(_kinds('text\n# head\nmore'), <MdBlockKind>[
        MdBlockKind.paragraph,
        MdBlockKind.heading,
        MdBlockKind.paragraph,
      ]);
    });

    test('every kind in one note appears in source order', () {
      expect(
        _kinds('# a\n- b\n1. c\n> d\n```\ne\n```\n---\n![f](photo/aa)\ng'),
        <MdBlockKind>[
          MdBlockKind.heading,
          MdBlockKind.bulletList,
          MdBlockKind.orderedList,
          MdBlockKind.blockQuote,
          MdBlockKind.fencedCode,
          MdBlockKind.thematicBreak,
          MdBlockKind.photoLine,
          MdBlockKind.paragraph,
        ],
      );
    });

    test('double stars are bold', () {
      final MdBlock block = _single('**bold**');
      expect(block.kind, MdBlockKind.paragraph);
      final MdInline strong = block.inlines.single;
      expect(strong.kind, MdInlineKind.strong);
      expect(strong.sourceRange, const MdRange(0, 8));
      expect(strong.contentRange, const MdRange(2, 6));
      expect(strong.markerRanges, const <MdRange>[
        MdRange(0, 2),
        MdRange(6, 8),
      ]);
      expect(plainTextOf('**bold**'), 'bold');
    });

    test('single stars and underscores are italic', () {
      for (final String source in <String>['*it*', '_it_']) {
        expect(
          _single(source).inlines.single.kind,
          MdInlineKind.emphasis,
          reason: source,
        );
      }
    });

    test('double tildes strike', () {
      expect(
        _single('~~gone~~').inlines.single.kind,
        MdInlineKind.strikethrough,
      );
      expect(plainTextOf('~~gone~~'), 'gone');
    });

    test('backticks make a literal code span', () {
      const String source = 'see `**raw**` here';
      final List<MdInline> inlines = _single(source).inlines;
      expect(_inlineKinds(inlines), <MdInlineKind>[
        MdInlineKind.text,
        MdInlineKind.codeSpan,
        MdInlineKind.text,
      ]);
      expect(inlines[1].sourceRange, const MdRange(4, 13));
      expect(inlines[1].contentRange, const MdRange(5, 12));
      expect(_hasInline(source, MdInlineKind.strong), isFalse);
    });

    test('a link carries its text, url and ranges', () {
      const String source = '[the sea](https://x.y)';
      final MdInline link = _single(source).inlines.single;
      expect(link.kind, MdInlineKind.link);
      expect(link.sourceRange, const MdRange(0, 22));
      expect(link.contentRange, const MdRange(1, 8));
      final MdLinkData data = link.data! as MdLinkData;
      expect(data.destination, 'https://x.y');
      expect(data.destinationRange, const MdRange(10, 21));
      expect(plainTextOf(source), 'the sea');
    });

    test('styles nest', () {
      const String source = '**a *b* c**';
      final MdInline strong = _single(source).inlines.single;
      expect(strong.kind, MdInlineKind.strong);
      expect(_inlineKinds(strong.children), <MdInlineKind>[
        MdInlineKind.text,
        MdInlineKind.emphasis,
        MdInlineKind.text,
      ]);
      expect(_content(strong.children[1], source), 'b');
      expect(plainTextOf(source), 'a b c');
    });

    test('unmatched delimiters stay literal in one plain run', () {
      for (final String source in <String>['**a', 'a**', '`a', '[a](', '~a~']) {
        for (final MdInlineKind kind in <MdInlineKind>[
          MdInlineKind.emphasis,
          MdInlineKind.strong,
          MdInlineKind.codeSpan,
          MdInlineKind.link,
          MdInlineKind.strikethrough,
        ]) {
          expect(_hasInline(source, kind), isFalse, reason: '$source $kind');
        }
        expect(plainTextOf(source), source, reason: source);
      }
      final MdBlock star = _single('*');
      expect(star.kind, MdBlockKind.bulletList);
      expect(star.blocks.single.kind, MdBlockKind.listItem);
      expect(star.blocks.single.blocks, isEmpty);
      expect(plainTextOf('*'), '');
    });

    test('a delimiter beside whitespace does not open or close', () {
      for (final String source in <String>['** a **', 'a * b']) {
        expect(_hasInline(source, MdInlineKind.emphasis), isFalse);
        expect(_hasInline(source, MdInlineKind.strong), isFalse);
      }
    });

    test('underscores inside a word do not italicise', () {
      expect(_hasInline('snake_case_name', MdInlineKind.emphasis), isFalse);
      expect(plainTextOf('snake_case_name'), 'snake_case_name');
    });

    test('a link needs a non-empty text and a whitespace-free url', () {
      final MdInline empty = _single('[](u)').inlines.single;
      expect(empty.kind, MdInlineKind.link);
      expect(empty.contentRange.isEmpty, isTrue);
      expect((empty.data! as MdLinkData).destination, 'u');
      final MdInline bare = _single('[a]()').inlines.single;
      expect(bare.kind, MdInlineKind.link);
      expect((bare.data! as MdLinkData).destination, '');
      expect(_hasInline('[a](b c)', MdInlineKind.link), isFalse);
    });

    test('inline formatting does not cross a line break', () {
      final MdInline strong = _single('**a\nb**').inlines.single;
      expect(strong.kind, MdInlineKind.strong);
      expect(_inlineKinds(strong.children), <MdInlineKind>[
        MdInlineKind.text,
        MdInlineKind.softBreak,
        MdInlineKind.text,
      ]);
      expect(plainTextOf('**a\nb**'), 'a\nb');
    });

    test('quote lines are tokenised per line around their markers', () {
      final MdBlock quote = _single('> **a**\n> *b*');
      expect(quote.kind, MdBlockKind.blockQuote);
      final List<MdInline> inlines = quote.blocks.single.inlines;
      expect(_inlineKinds(inlines), <MdInlineKind>[
        MdInlineKind.strong,
        MdInlineKind.softBreak,
        MdInlineKind.emphasis,
      ]);
      expect(
        <MdRange>[for (final MdInline inline in inlines) inline.sourceRange],
        const <MdRange>[MdRange(2, 7), MdRange(7, 8), MdRange(10, 13)],
      );
    });

    test('block source ranges concatenate back to the source', () {
      _checkTopLevelTiling();
    });

    test('block ranges tile the source from zero without gaps', () {
      _checkTopLevelTiling();
    });

    test('inline and marker ranges stay ordered inside their block', () {
      for (final (int index, String source) in noteFuzzCorpus.indexed) {
        for (final MdNode node in _treeNodes(
          parseNoteTree(source, tables: true),
        )) {
          final String reason = 'corpus #$index $node';
          expect(
            _inside(node.contentRange, node.sourceRange),
            isTrue,
            reason: reason,
          );
          for (final MdRange marker in node.markerRanges) {
            expect(_inside(marker, node.sourceRange), isTrue, reason: reason);
          }
          for (final MdNode child in node.children) {
            expect(
              _inside(child.sourceRange, node.sourceRange),
              isTrue,
              reason: reason,
            );
          }
          _expectOrdered(node.markerRanges, reason);
          _expectOrdered(<MdRange>[
            for (final MdNode child in node.children) child.sourceRange,
          ], reason);
        }
      }
    });

    test('plain leaves carry the text their range names', () {
      for (final (int index, String source) in noteFuzzCorpus.indexed) {
        final List<MdNode> nodes = _treeNodes(
          parseNoteTree(source, tables: true),
        ).toList();
        final List<MdRange> markers = <MdRange>[
          for (final MdNode node in nodes) ...node.markerRanges,
        ];
        for (final MdInline inline in nodes.whereType<MdInline>()) {
          final String reason = 'corpus #$index $inline';
          if (inline.kind == MdInlineKind.text) {
            expect(inline.sourceRange.isEmpty, isFalse, reason: reason);
            expect(
              markers.where(
                (MdRange marker) => _overlaps(marker, inline.sourceRange),
              ),
              isEmpty,
              reason: reason,
            );
          }
          if (inline.kind == MdInlineKind.codeSpan) {
            expect(
              _inside(inline.contentRange, inline.sourceRange),
              isTrue,
              reason: reason,
            );
          }
        }
      }
    });

    test('a repeat call on the same source returns the identical list', () {
      _checkMemoReplacedByDeterminism();
    });

    test('an equal but distinct string also hits the memo', () {
      _checkMemoReplacedByDeterminism();
    });

    test('the returned list is unmodifiable', () {
      final MdTree tree = parseNoteTree('- a\n- b\n\npara **x**');
      final MdBlock list = tree.blocks.first;
      final MdBlock paragraph = tree.blocks.last;
      expect(list.kind, MdBlockKind.bulletList);
      expect(paragraph.kind, MdBlockKind.paragraph);
      expect(() => tree.blocks.clear(), throwsUnsupportedError);
      expect(() => list.blocks.add(list.blocks.first), throwsUnsupportedError);
      expect(() => paragraph.inlines.clear(), throwsUnsupportedError);
    });
  });
}
