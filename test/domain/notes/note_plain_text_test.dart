import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/domain/notes/note_plain_text.dart';
import 'package:flutter_test/flutter_test.dart';

import 'note_fuzz_corpus.dart';

const String _markers = r'#*_~`[]()>!';

void main() {
  group('plainTextOf', () {
    test('leaves plain prose byte-identical', () {
      const String prose =
          'a quiet morning\nrain on the roof\n\nand a walk in the afternoon';
      expect(plainTextOf(prose), prose);
    });

    test('strips every block marker in the closed set', () {
      expect(plainTextOf('# Title'), 'Title');
      expect(plainTextOf('## Title'), 'Title');
      expect(plainTextOf('### Title'), 'Title');
      expect(plainTextOf('- milk'), 'milk');
      expect(plainTextOf('3. eggs'), 'eggs');
      expect(plainTextOf('> quoted\n> twice'), 'quoted\ntwice');
      expect(plainTextOf('```dart\nlet x\n```'), 'let x');
      expect(plainTextOf('---'), '');
    });

    test('strips every inline marker in the closed set', () {
      expect(plainTextOf('**bold** *it* _it_ ~~gone~~ `code` [sea](https://x)'),
          'bold it it gone code sea');
      expect(plainTextOf('**a *b* c**'), 'a b c');
    });

    test('projects a photo block to its alt text', () {
      expect(plainTextOf('![a walk](photo/0123456789ab "right medium")'),
          'a walk');
      expect(plainTextOf('![](photo/0123456789ab)'), '');
    });

    test('a photo-first note projects to its caption then its prose', () {
      expect(
        plainTextOf('![the harbour](photo/0123456789ab)\n\nwe sailed'),
        'the harbour\n\nwe sailed',
      );
    });

    test('separates blocks with a paragraph break and list items with one',
        () {
      expect(plainTextOf('# T\n\nbody\n\n\n\nmore'), 'T\n\nbody\n\nmore');
      expect(plainTextOf('- a\n- b\n1. c\n\ntext'), 'a\nb\nc\n\ntext');
    });

    test('skips blocks that project to nothing', () {
      expect(plainTextOf('a\n\n---\n\nb'), 'a\n\nb');
      expect(plainTextOf('![](photo/0123456789ab)\n\nb'), 'b');
      expect(plainTextOf('---'), '');
    });

    test('carries no marker for a corpus source built from markers only', () {
      const String source = '# **Bold** _head_\n\n- `x`\n> ~~y~~\n---\n'
          '![z](photo/0123456789ab "left large")';
      final String plain = plainTextOf(source);
      for (final String marker in _markers.split('')) {
        expect(plain.contains(marker), isFalse, reason: marker);
      }
      expect(plain, 'Bold head\n\nx\n\ny\n\nz');
    });

    test('is total over the fuzz corpus', () {
      for (final String source in noteFuzzCorpus) {
        expect(plainTextOf(source), isA<String>(), reason: source);
      }
    });

    test('plain text follows the new grammar', () {
      const Map<String, String> pairs = <String, String>{
        '- eggs\nThen we left.': 'eggs\nThen we left.',
        '> "Quote"\n\u2014 Author': '"Quote"\n\u2014 Author',
        '- a\n  detail': 'a\ndetail',
        '- a\n\t- b': 'a\nb',
        '- a\n    - b': 'a\nb',
        '[label]()': 'label',
        '**line one\nline two**': 'line one\nline two',
        'Windows:\n14. doors': 'Windows:\n14. doors',
        '\u00af\\_(\u30c4)_/\u00af': '\u00af_(\u30c4)_/\u00af',
        r'a \* b': 'a * b',
        'end\\\nnext': 'end\nnext',
        '***a***': 'a',
        '``a``': 'a',
        '# Title #': 'Title',
        '#### x': 'x',
        '###### x': 'x',
        '~~~\ncode': 'code',
        '<https://x>': 'https://x',
        '[a](b(c))': 'a',
        '[a](u "t")': 'a',
        'x==y==': 'xy',
        '> > x': 'x',
        '> - x': 'x',
        '> # x': 'x',
        '- [ ] x': 'x',
        '- [x] packed': 'packed',
        '- a\n  ![p](photo/abc123abc123)': 'a\n!p',
      };
      for (final MapEntry<String, String> pair in pairs.entries) {
        expect(plainTextOf(pair.key), pair.value, reason: pair.key);
      }
    });
  });

  group('notePlainSegments', () {
    const String mixed = '# T\n\n- a\n- b\n\n![c](photo/abc123abc123)\n\n'
        '| x |\n| - |\n| y |';

    test('walks headings, items, photos and tables in source order', () {
      expect(
        notePlainSegments(parseNoteTree(mixed), mixed),
        const <NotePlainSegment>[
          NotePlainSegment(kind: NotePlainKind.heading, text: 'T'),
          NotePlainSegment(kind: NotePlainKind.listItem, text: 'a'),
          NotePlainSegment(kind: NotePlainKind.listItem, text: 'b'),
          NotePlainSegment(kind: NotePlainKind.photo, text: 'c'),
          NotePlainSegment(kind: NotePlainKind.table, text: 'x\ny'),
        ],
      );
    });

    test('a table is cells joined by tabs, or pipe text with tables off', () {
      expect(plainTextOf(mixed), 'T\n\na\nb\n\nc\n\nx\ny');
      expect(
        plainTextOf(mixed, tables: false),
        'T\n\na\nb\n\nc\n\n| x |\n| - |\n| y |',
      );
      expect(plainTextOf('| a | b |\n| - | - |\n| c | d |'), 'a\tb\nc\td');
    });

    test('a CRLF is one line break and a lone CR is content', () {
      expect(plainTextOf('one\r\ntwo'), 'one\ntwo');
      expect(plainTextOf('one\rtwo'), 'one\rtwo');
    });

    test('code drops its fences, fence indentation and trailing blanks', () {
      expect(plainTextOf('```\ncode\n\n'), 'code');
      expect(plainTextOf(' ```\n code\n ```'), 'code');
      expect(plainTextOf('```\n   '), '');
      expect(plainTextOf('a\n\n```\n   '), 'a');
    });

    test('items join by one break and other blocks by a paragraph break', () {
      expect(plainTextOf('- a\n\n  more'), 'a\n\nmore');
      expect(plainTextOf('- a\n\n- b'), 'a\nb');
      expect(plainTextOf('1. a\n2) b'), 'a\nb');
      expect(plainTextOf('- # x'), 'x');
      expect(plainTextOf('- a\n![p](photo/abc123abc123)'), 'a\n\np');
      expect(plainTextOf('> q\n![p](photo/abc123abc123)'), 'q\n\np');
    });

    test('an empty or blank source gives no text', () {
      expect(plainTextOf(''), '');
      expect(plainTextOf('\n \n'), '');
    });

    test('marker whitespace goes with the markers', () {
      expect(plainTextOf('a  \nb'), 'a\nb');
      expect(plainTextOf('  indented'), 'indented');
    });

    test('the join skips empty segments before choosing a break', () {
      expect(
        joinNotePlainSegments(const <NotePlainSegment>[
          NotePlainSegment(kind: NotePlainKind.listItem, text: 'a'),
          NotePlainSegment(kind: NotePlainKind.heading, text: ''),
          NotePlainSegment(kind: NotePlainKind.listItem, text: 'b'),
        ]),
        'a\nb',
      );
      expect(
        joinNotePlainSegments(const <NotePlainSegment>[
          NotePlainSegment(kind: NotePlainKind.paragraph, text: 'a'),
          NotePlainSegment(kind: NotePlainKind.photo, text: ''),
          NotePlainSegment(kind: NotePlainKind.paragraph, text: 'b'),
        ]),
        'a\n\nb',
      );
    });

    test('a segment compares by value', () {
      final String text = String.fromCharCodes(<int>[0x61]);
      expect(
        NotePlainSegment(kind: NotePlainKind.code, text: text),
        const NotePlainSegment(kind: NotePlainKind.code, text: 'a'),
      );
      expect(
        NotePlainSegment(kind: NotePlainKind.code, text: text).hashCode,
        const NotePlainSegment(kind: NotePlainKind.code, text: 'a').hashCode,
      );
      expect(
        const NotePlainSegment(kind: NotePlainKind.code, text: 'a'),
        isNot(const NotePlainSegment(kind: NotePlainKind.paragraph, text: 'a')),
      );
    });
  });
}
