import 'package:field_notes/domain/notes/notes.dart';
import 'package:flutter_test/flutter_test.dart';

import 'note_fuzz_corpus.dart';

NoteBlock single(String source) => parseNote(source).single;

String rangesJoined(String source) =>
    parseNote(source).map((NoteBlock b) => b.sourceRange.sliceOf(source)).join();

List<String> kinds(String source) =>
    parseNote(source).map((NoteBlock b) => b.runtimeType.toString()).toList();

void main() {
  group('parseNote block classification', () {
    test('empty source yields no blocks', () {
      expect(parseNote(''), isEmpty);
    });

    test('a whitespace-only source yields one empty paragraph', () {
      final NoteBlock block = single('\n \n');
      expect(block, isA<ParagraphBlock>());
      expect(block.plainText, '');
      expect(block.sourceRange, const SourceRange(0, 3));
    });

    test('plain lines form one paragraph with a soft break', () {
      final ParagraphBlock block = single('one\ntwo') as ParagraphBlock;
      expect(block.plainText, 'one\ntwo');
      expect(block.inlines.single, isA<PlainNode>());
      expect(block.inlines.single.sourceRange, const SourceRange(0, 7));
    });

    test('a blank line separates paragraphs', () {
      expect(kinds('one\n\ntwo'), <String>['ParagraphBlock', 'ParagraphBlock']);
    });

    test('headings run from one to three hashes followed by a space', () {
      for (int level = 1; level <= 3; level++) {
        final HeadingBlock block =
            single('${'#' * level} Title') as HeadingBlock;
        expect(block.level, level);
        expect(block.plainText, 'Title');
        expect(block.markerRanges, <SourceRange>[SourceRange(0, level + 1)]);
      }
    });

    test('four hashes and a hashtag are paragraphs', () {
      expect(single('#### deep'), isA<ParagraphBlock>());
      expect(single('#hashtag'), isA<ParagraphBlock>());
      expect(single('#hashtag').plainText, '#hashtag');
    });

    test('a bare hash is an empty heading', () {
      final HeadingBlock block = single('#') as HeadingBlock;
      expect(block.level, 1);
      expect(block.plainText, '');
    });

    test('bullets accept dash, star and plus markers', () {
      for (final String marker in <String>['-', '*', '+']) {
        final BulletBlock block = single('$marker milk') as BulletBlock;
        expect(block.plainText, 'milk');
        expect(block.markerRanges, <SourceRange>[const SourceRange(0, 2)]);
      }
    });

    test('a marker without a following space is a paragraph', () {
      expect(single('-milk'), isA<ParagraphBlock>());
      expect(single('1.milk'), isA<ParagraphBlock>());
    });

    test('numbered items keep the typed ordinal', () {
      final NumberBlock block = single('12) eggs') as NumberBlock;
      expect(block.ordinal, 12);
      expect(block.plainText, 'eggs');
      expect(block.markerRanges, <SourceRange>[const SourceRange(0, 4)]);
    });

    test('consecutive list lines are separate blocks', () {
      expect(kinds('- a\n- b\n1. c'), <String>[
        'BulletBlock',
        'BulletBlock',
        'NumberBlock',
      ]);
    });

    test('consecutive quote lines merge into one quote', () {
      final QuoteBlock block = single('> one\n> two') as QuoteBlock;
      expect(block.plainText, 'one\ntwo');
      expect(block.markerRanges, <SourceRange>[
        const SourceRange(0, 2),
        const SourceRange(6, 8),
      ]);
    });

    test('a plain line after a quote starts a paragraph', () {
      expect(kinds('> one\ntwo'), <String>['QuoteBlock', 'ParagraphBlock']);
    });

    test('a fenced code block keeps raw content and a language', () {
      final CodeBlock block =
          single('```dart\n# raw\n- raw\n```') as CodeBlock;
      expect(block.language, 'dart');
      expect(block.text, '# raw\n- raw');
      expect(block.contentRange, const SourceRange(8, 19));
      expect(block.markerRanges, <SourceRange>[
        const SourceRange(0, 7),
        const SourceRange(20, 23),
      ]);
    });

    test('an unclosed fence runs to the end of the note', () {
      final CodeBlock block = single('```\ncode\n\n') as CodeBlock;
      expect(block.text, 'code');
      expect(block.markerRanges, <SourceRange>[const SourceRange(0, 3)]);
      expect(block.sourceRange, const SourceRange(0, 10));
    });

    test('a closing fence must be at least as long as the opener', () {
      final CodeBlock block = single('````\n```\n````') as CodeBlock;
      expect(block.text, '```');
    });

    test('dividers accept dashes, stars and underscores with spaces', () {
      for (final String line in <String>['---', '***', '___', '- - -', '----']) {
        expect(single(line), isA<DividerBlock>(), reason: line);
        expect(single(line).plainText, '');
      }
      expect(single('--'), isA<ParagraphBlock>());
    });

    test('a photo line parses alt, reference and attributes', () {
      final PhotoBlock block =
          single('![a walk](photo/0123456789ab "right medium")') as PhotoBlock;
      expect(block.alt, 'a walk');
      expect(block.reference, '0123456789ab');
      expect(block.attributes, 'right medium');
      expect(block.altRange, const SourceRange(2, 8));
      expect(block.referenceRange, const SourceRange(16, 28));
      expect(block.attributesRange, const SourceRange(30, 42));
      expect(block.markerRanges, <SourceRange>[const SourceRange(0, 44)]);
      expect(block.plainText, 'a walk');
    });

    test('a photo line without attributes has an empty attribute slot', () {
      final PhotoBlock block = single('![](photo/ab)') as PhotoBlock;
      expect(block.alt, '');
      expect(block.attributes, '');
      expect(block.attributesRange, isNull);
      expect(block.markerRanges, <SourceRange>[const SourceRange(0, 13)]);
    });

    test('an image that is not a photo reference stays prose', () {
      expect(single('![a](http://x)'), isA<ParagraphBlock>());
      expect(single('![a](photo/ab) trailing'), isA<ParagraphBlock>());
      expect(single('![a](photo/)'), isA<ParagraphBlock>());
    });

    test('a marker line ends the paragraph before it', () {
      expect(kinds('text\n# head\nmore'), <String>[
        'ParagraphBlock',
        'HeadingBlock',
        'ParagraphBlock',
      ]);
    });

    test('every kind in one note appears in source order', () {
      expect(
        kinds('# a\n- b\n1. c\n> d\n```\ne\n```\n---\n![f](photo/aa)\ng'),
        <String>[
          'HeadingBlock',
          'BulletBlock',
          'NumberBlock',
          'QuoteBlock',
          'CodeBlock',
          'DividerBlock',
          'PhotoBlock',
          'ParagraphBlock',
        ],
      );
    });
  });

  group('parseNote inline tokenizing', () {
    List<InlineNode> inlinesOf(String line) =>
        (single(line) as InlineBlock).inlines;

    test('double stars are bold', () {
      final StyledNode node = inlinesOf('**bold**').single as StyledNode;
      expect(node.style, InlineStyle.bold);
      expect(node.plainText, 'bold');
      expect(node.sourceRange, const SourceRange(0, 8));
      expect(node.contentRange, const SourceRange(2, 6));
    });

    test('single stars and underscores are italic', () {
      expect((inlinesOf('*it*').single as StyledNode).style, InlineStyle.italic);
      expect((inlinesOf('_it_').single as StyledNode).style, InlineStyle.italic);
    });

    test('double tildes strike', () {
      final StyledNode node = inlinesOf('~~gone~~').single as StyledNode;
      expect(node.style, InlineStyle.strike);
      expect(node.plainText, 'gone');
    });

    test('backticks make a literal code span', () {
      final List<InlineNode> nodes = inlinesOf('see `**raw**` here');
      expect(nodes, hasLength(3));
      final CodeNode code = nodes[1] as CodeNode;
      expect(code.text, '**raw**');
      expect(code.sourceRange, const SourceRange(4, 13));
      expect(code.contentRange, const SourceRange(5, 12));
    });

    test('a link carries its text, url and ranges', () {
      final LinkNode node =
          inlinesOf('[the sea](https://x.y)').single as LinkNode;
      expect(node.plainText, 'the sea');
      expect(node.url, 'https://x.y');
      expect(node.contentRange, const SourceRange(1, 8));
      expect(node.urlRange, const SourceRange(10, 21));
      expect(node.sourceRange, const SourceRange(0, 22));
    });

    test('styles nest', () {
      final StyledNode outer = inlinesOf('**a *b* c**').single as StyledNode;
      expect(outer.style, InlineStyle.bold);
      expect(outer.children, hasLength(3));
      expect((outer.children[1] as StyledNode).style, InlineStyle.italic);
      expect(outer.plainText, 'a b c');
    });

    test('unmatched delimiters stay literal in one plain run', () {
      for (final String line in <String>['**a', 'a**', '*', '`a', '[a](', '~a~']) {
        final List<InlineNode> nodes = inlinesOf(line);
        expect(nodes.single, isA<PlainNode>(), reason: line);
        expect(nodes.single.plainText, line, reason: line);
      }
    });

    test('a delimiter beside whitespace does not open or close', () {
      expect(inlinesOf('** a **').single, isA<PlainNode>());
      expect(inlinesOf('a * b').single, isA<PlainNode>());
    });

    test('underscores inside a word do not italicise', () {
      expect(inlinesOf('snake_case_name').single, isA<PlainNode>());
      expect(inlinesOf('snake_case_name').single.plainText, 'snake_case_name');
    });

    test('a link needs a non-empty text and a whitespace-free url', () {
      expect(inlinesOf('[](u)').single, isA<PlainNode>());
      expect(inlinesOf('[a]()').single, isA<PlainNode>());
      expect(inlinesOf('[a](b c)').single, isA<PlainNode>());
    });

    test('inline formatting does not cross a line break', () {
      final ParagraphBlock block = single('**a\nb**') as ParagraphBlock;
      expect(block.inlines.single, isA<PlainNode>());
      expect(block.plainText, '**a\nb**');
    });

    test('quote lines are tokenised per line around their markers', () {
      final QuoteBlock block = single('> **a**\n> *b*') as QuoteBlock;
      expect(block.inlines.map((InlineNode n) => n.runtimeType.toString()),
          <String>['StyledNode', 'PlainNode', 'StyledNode']);
      expect(block.inlines[1].sourceRange, const SourceRange(7, 8));
      expect(block.inlines[2].sourceRange, const SourceRange(10, 13));
    });
  });

  group('parseNote losslessness over the fuzz corpus', () {
    test('block source ranges concatenate back to the source', () {
      for (final String source in noteFuzzCorpus) {
        expect(rangesJoined(source), source, reason: source);
      }
    });

    test('block ranges tile the source from zero without gaps', () {
      for (final String source in noteFuzzCorpus) {
        int cursor = 0;
        for (final NoteBlock block in parseNote(source)) {
          expect(block.sourceRange.start, cursor, reason: source);
          cursor = block.sourceRange.end;
        }
        expect(cursor, source.length, reason: source);
      }
    });

    test('inline and marker ranges stay ordered inside their block', () {
      for (final String source in noteFuzzCorpus) {
        for (final NoteBlock block in parseNote(source)) {
          final List<SourceRange> ranges = <SourceRange>[
            ...block.markerRanges,
            if (block is InlineBlock) ..._leafRanges(block.inlines),
          ]..sort((SourceRange a, SourceRange b) => a.start - b.start);
          int cursor = block.sourceRange.start;
          for (final SourceRange range in ranges) {
            expect(range.start, greaterThanOrEqualTo(cursor), reason: source);
            expect(range.end, lessThanOrEqualTo(block.sourceRange.end),
                reason: source);
            cursor = range.end;
          }
        }
      }
    });

    test('plain leaves carry the text their range names', () {
      for (final String source in noteFuzzCorpus) {
        if (source.contains('\r')) {
          continue;
        }
        for (final NoteBlock block in parseNote(source)) {
          if (block is! InlineBlock) {
            continue;
          }
          for (final InlineNode node in _leaves(block.inlines)) {
            switch (node) {
              case PlainNode(:final String text, :final SourceRange sourceRange):
                expect(sourceRange.sliceOf(source), text, reason: source);
              case CodeNode(:final String text, :final SourceRange contentRange):
                expect(contentRange.sliceOf(source), text, reason: source);
              default:
                break;
            }
          }
        }
      }
    });
  });

  group('parseNote memoization', () {
    test('a repeat call on the same source returns the identical list', () {
      const String source = '# same\n\n**note**';
      final List<NoteBlock> first = parseNote(source);
      expect(identical(parseNote(source), first), isTrue);
      expect(identical(parseNote('$source '), first), isFalse);
      expect(identical(parseNote(source), first), isTrue);
    });

    test('an equal but distinct string also hits the memo', () {
      final String a = 'memo ${DateTime(2026).year}';
      final String b = 'memo ${DateTime(2026).year}';
      expect(identical(parseNote(a), parseNote(b)), isTrue);
    });

    test('the returned list is unmodifiable', () {
      expect(() => parseNote('a').clear(), throwsUnsupportedError);
    });
  });
}

List<SourceRange> _leafRanges(List<InlineNode> nodes) =>
    <SourceRange>[for (final InlineNode node in nodes) node.sourceRange];

Iterable<InlineNode> _leaves(List<InlineNode> nodes) sync* {
  for (final InlineNode node in nodes) {
    switch (node) {
      case StyledNode(:final List<InlineNode> children):
        yield* _leaves(children);
      case LinkNode(:final List<InlineNode> children):
        yield* _leaves(children);
      default:
        yield node;
    }
  }
}
