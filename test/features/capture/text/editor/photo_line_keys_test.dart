import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/features/capture/text/editor/photo_line_keys.dart';

import '../../../notes/support/notes_harness.dart' show photoIdA, photoLine;

TextEditingValue _at(String text, int caret) => TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: caret),
    );

TextEditingValue _range(String text, int start, int end) => TextEditingValue(
      text: text,
      selection: TextSelection(baseOffset: start, extentOffset: end),
    );

void main() {
  final String a = photoLine(photoIdA);
  final String note = 'one\n$a\ntwo';
  final int photoStart = note.indexOf(a);
  final int photoEnd = photoStart + a.length;
  final int inPhoto = photoStart + 5;
  final int twoStart = note.indexOf('two');

  group('photoAwareDelete', () {
    test('removes the whole photo line when the photo is selected', () {
      for (final bool forward in <bool>[false, true]) {
        final TextEditingValue? next =
            photoAwareDelete(_at(note, inPhoto), forward: forward);

        expect(next?.text, 'one\ntwo');
        expect(next?.selection, const TextSelection.collapsed(offset: 4));
      }
    });

    test('Backspace at the start of the line after a photo selects it', () {
      final TextEditingValue? next =
          photoAwareDelete(_at(note, twoStart), forward: false);

      expect(next?.text, note);
      expect(next!.selection.baseOffset, inInclusiveRange(photoStart, photoEnd));
    });

    test('Delete at the end of the line before a photo selects it', () {
      final TextEditingValue? next =
          photoAwareDelete(_at(note, 3), forward: true);

      expect(next?.text, note);
      expect(next!.selection.baseOffset, inInclusiveRange(photoStart, photoEnd));
    });

    test('leaves plain text and range deletions to the default', () {
      expect(photoAwareDelete(_at(note, 2), forward: false), isNull);
      expect(photoAwareDelete(_at(note, twoStart + 1), forward: false), isNull);
      expect(photoAwareDelete(_range(note, 0, 2), forward: false), isNull);
    });
  });

  group('photoAwareStep', () {
    test('crosses a selected photo in one step each way', () {
      expect(
        photoAwareStep(_at(note, inPhoto), forward: true, collapse: true)
            ?.selection,
        TextSelection.collapsed(offset: twoStart),
      );
      expect(
        photoAwareStep(_at(note, inPhoto), forward: false, collapse: true)
            ?.selection,
        const TextSelection.collapsed(offset: 3),
      );
    });

    test('extends a selection across a photo in one step', () {
      final TextEditingValue value = TextEditingValue(
        text: note,
        selection: TextSelection(baseOffset: 1, extentOffset: inPhoto),
      );

      expect(
        photoAwareStep(value, forward: true, collapse: false)?.selection,
        TextSelection(baseOffset: 1, extentOffset: twoStart),
      );
    });

    test('leaves a caret outside a photo to the default', () {
      expect(
        photoAwareStep(_at(note, 1), forward: true, collapse: true),
        isNull,
      );
    });
  });

  group('deselectPhoto', () {
    test('moves the caret to the line after the photo', () {
      expect(
        deselectPhoto(_at(note, inPhoto))?.selection,
        TextSelection.collapsed(offset: twoStart),
      );
    });

    test('a photo on the last line deselects to the line before it', () {
      final String last = 'one\n$a';

      expect(
        deselectPhoto(_at(last, last.indexOf(a) + 5))?.selection,
        const TextSelection.collapsed(offset: 3),
      );
    });

    test('does nothing without a selected photo', () {
      expect(deselectPhoto(_at(note, 1)), isNull);
    });
  });

  group('PhotoLineGuard', () {
    const PhotoLineGuard guard = PhotoLineGuard();

    TextEditingValue typed(TextEditingValue before, String inserted) {
      final int caret = before.selection.baseOffset;
      return guard.formatEditUpdate(
        before,
        TextEditingValue(
          text: before.text.replaceRange(caret, caret, inserted),
          selection: TextSelection.collapsed(offset: caret + inserted.length),
        ),
      );
    }

    test('typing on a selected photo starts a new line after it', () {
      final TextEditingValue next = typed(_at(note, inPhoto), 'x');

      expect(next.text, 'one\n$a\nx\ntwo');
      expect(next.selection, TextSelection.collapsed(offset: photoEnd + 2));
    });

    test('Enter on a selected photo opens an empty line after it', () {
      final TextEditingValue next = typed(_at(note, inPhoto), '\n');

      expect(next.text, 'one\n$a\n\ntwo');
      expect(next.selection, TextSelection.collapsed(offset: photoEnd + 1));
    });

    test('an IME composition on a selected photo moves with the text', () {
      final TextEditingValue before = _at(note, inPhoto);
      final TextEditingValue next = guard.formatEditUpdate(
        before,
        TextEditingValue(
          text: note.replaceRange(inPhoto, inPhoto, 'か'),
          selection: TextSelection.collapsed(offset: inPhoto + 1),
          composing: TextRange(start: inPhoto, end: inPhoto + 1),
        ),
      );

      expect(next.text, 'one\n$a\nか\ntwo');
      expect(
        next.composing,
        TextRange(start: photoEnd + 1, end: photoEnd + 2),
      );
    });

    test('replacing part of a photo line takes the whole line', () {
      final TextEditingValue before = _range(note, 1, inPhoto);
      final TextEditingValue next = guard.formatEditUpdate(
        before,
        TextEditingValue(
          text: note.replaceRange(1, inPhoto, 'y'),
          selection: const TextSelection.collapsed(offset: 2),
        ),
      );

      expect(next.text, 'oy\ntwo');
      expect(next.selection, const TextSelection.collapsed(offset: 2));
    });

    test('deleting the break after a photo keeps the photo on its own line',
        () {
      final TextEditingValue before = _range(note, photoEnd, twoStart + 1);
      final TextEditingValue next = guard.formatEditUpdate(
        before,
        TextEditingValue(
          text: note.replaceRange(photoEnd, twoStart + 1, ''),
          selection: TextSelection.collapsed(offset: photoEnd),
        ),
      );

      expect(next.text, 'one\n$a\nwo');
    });

    test('deleting the break before a photo keeps the photo on its own line',
        () {
      final TextEditingValue before = _range(note, 2, photoStart);
      final TextEditingValue next = guard.formatEditUpdate(
        before,
        TextEditingValue(
          text: note.replaceRange(2, photoStart, ''),
          selection: const TextSelection.collapsed(offset: 2),
        ),
      );

      expect(next.text, 'on\n$a\ntwo');
    });

    test('typing away from photos passes through untouched', () {
      final TextEditingValue next = typed(_at(note, 1), 'z');

      expect(next.text, 'ozne\n$a\ntwo');
    });
  });
}
