import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/notes/notes.dart';
import 'package:field_notes/features/entry_cards/notes/inline_span_slice.dart';
import 'package:field_notes/features/entry_cards/notes/note_inline_span.dart';

import '../../../domain/notes/note_fuzz_corpus.dart';

const TextStyle _base = TypographyTokens.noteBody;
const TextStyle _bold = TextStyle(fontWeight: FontWeight.w700);
const TextStyle _italic = TextStyle(fontStyle: FontStyle.italic);

String _plain(InlineSpan? span) => span?.toPlainText() ?? '';

Iterable<TextSpan> _walk(InlineSpan span) sync* {
  if (span is TextSpan) {
    yield span;
    for (final InlineSpan child in span.children ?? const <InlineSpan>[]) {
      yield* _walk(child);
    }
  }
}

void main() {
  group('sliceInlineSpan', () {
    test('head plus tail is the root plain text at every offset', () {
      for (final String source in noteFuzzCorpus) {
        for (final NoteBlock block in parseNote(source)) {
          if (block is! InlineBlock) {
            continue;
          }
          final TextSpan root = buildNoteInlineSpan(block.inlines, _base);
          final String whole = root.toPlainText();
          for (int offset = 0; offset <= whole.length; offset++) {
            final (InlineSpan head, InlineSpan? tail) =
                sliceInlineSpan(root, offset);
            expect(_plain(head) + _plain(tail), whole,
                reason: '$source @ $offset');
            expect(_plain(head).length, offset, reason: '$source @ $offset');
          }
        }
      }
    });

    test('splitting inside a styled leaf keeps the style on both halves', () {
      const TextSpan root = TextSpan(
        style: _base,
        children: <InlineSpan>[
          TextSpan(text: 'plain '),
          TextSpan(text: 'bold', style: _bold),
          TextSpan(text: ' after'),
        ],
      );

      final (InlineSpan head, InlineSpan? tail) = sliceInlineSpan(root, 8);

      expect(head.toPlainText(), 'plain bo');
      expect(tail!.toPlainText(), 'ld after');
      expect(head.style, _base);
      expect(tail.style, _base);
      final TextSpan headBold =
          _walk(head).firstWhere((TextSpan s) => s.text == 'bo');
      final TextSpan tailBold =
          _walk(tail).firstWhere((TextSpan s) => s.text == 'ld');
      expect(headBold.style, _bold);
      expect(tailBold.style, _bold);
    });

    test('splitting at a nested-span boundary re-parents each ancestor', () {
      const TextSpan root = TextSpan(
        style: _base,
        children: <InlineSpan>[
          TextSpan(
            style: _italic,
            children: <InlineSpan>[
              TextSpan(text: 'ab'),
              TextSpan(text: 'cd', style: _bold),
            ],
          ),
          TextSpan(text: 'ef'),
        ],
      );

      final (InlineSpan head, InlineSpan? tail) = sliceInlineSpan(root, 2);

      expect(head.toPlainText(), 'ab');
      expect(tail!.toPlainText(), 'cdef');
      expect(head.style, _base);
      expect(tail.style, _base);
      final TextSpan headItalic = (head as TextSpan).children!.single as TextSpan;
      final TextSpan tailItalic = (tail as TextSpan).children!.first as TextSpan;
      expect(headItalic.style, _italic);
      expect(tailItalic.style, _italic);
      expect((tailItalic.children!.single as TextSpan).style, _bold);
    });

    test('offset zero yields an empty styled head and the root as tail', () {
      const TextSpan root = TextSpan(text: 'abc', style: _base);

      final (InlineSpan head, InlineSpan? tail) = sliceInlineSpan(root, 0);

      expect(head.toPlainText(), '');
      expect(head.style, _base);
      expect(identical(tail, root), isTrue);
    });

    test('an offset past the end yields the root and no tail', () {
      const TextSpan root = TextSpan(text: 'abc', style: _base);

      final (InlineSpan head, InlineSpan? tail) = sliceInlineSpan(root, 3);

      expect(identical(head, root), isTrue);
      expect(tail, isNull);
    });

    test('a placeholder span goes wholly to one side', () {
      final TextSpan root = TextSpan(
        style: _base,
        children: <InlineSpan>[
          const TextSpan(text: 'a'),
          WidgetSpan(child: Container()),
          const TextSpan(text: 'b'),
        ],
      );

      final (InlineSpan head, InlineSpan? tail) = sliceInlineSpan(root, 1);

      expect(head.toPlainText(), 'a');
      expect(tail!.toPlainText(), '￼b');
      expect(plainLengthOf(root), 3);
    });
  });
}
