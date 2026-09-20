import 'package:field_notes/domain/notes/notes.dart';
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
  });
}
