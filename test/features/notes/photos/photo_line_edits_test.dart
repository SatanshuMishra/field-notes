import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/features/notes/notes.dart';

import '../support/notes_harness.dart';

TextEditingValue _value(String text, [int? caret]) => TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: caret ?? text.length),
    );

NotePhotoLine _line(String text, [int ordinal = 0]) =>
    notePhotoLines(text)[ordinal];

void main() {
  final String a = photoLine(photoIdA);
  final String b = photoLine(photoIdB);
  final String c = photoLine(photoIdC, caption: 'porch light');

  group('notePhotoLines', () {
    test('locates every photo line by its physical line', () {
      final String source = 'one\n$a\n\ntwo\n$b';
      final List<NotePhotoLine> lines = notePhotoLines(source);

      expect(lines, hasLength(2));
      expect(lines[0].ordinal, 0);
      expect(lines[0].reference, prefixOf(photoIdA));
      expect(source.substring(lines[0].lineStart, lines[0].lineEnd), a);
      expect(lines[0].breakEnd, lines[0].lineEnd + 1);
      expect(lines[1].reference, prefixOf(photoIdB));
      expect(lines[1].lineEnd, source.length);
      expect(lines[1].breakEnd, source.length);
    });

    test('reads the caption from the alt slot and the placement from the title',
        () {
      final NotePhotoLine line = _line(
        photoLine(
          photoIdA,
          caption: 'the porch',
          side: PhotoSide.left,
          size: PhotoSize.large,
        ),
      );

      expect(line.caption, 'the porch');
      expect(line.placement.side, PhotoSide.left);
      expect(line.placement.size, PhotoSize.large);
    });

    test('ignores photo syntax inside a code fence', () {
      expect(notePhotoLines('```\n$a\n```'), isEmpty);
    });
  });

  group('photoLineIndexAtCaret', () {
    final String source = 'one\n$a\ntwo\n$b';

    test('answers the photo whose line holds the caret, at either end', () {
      final NotePhotoLine first = _line(source);
      final NotePhotoLine second = _line(source, 1);

      expect(photoLineIndexAtCaret(source, caretAt(first.lineStart)), 0);
      expect(photoLineIndexAtCaret(source, caretAt(first.lineEnd)), 0);
      expect(photoLineIndexAtCaret(source, caretAt(second.lineStart + 5)), 1);
    });

    test('is null on a text line or with no caret at all', () {
      expect(photoLineIndexAtCaret(source, caretAt(1)), isNull);
      expect(
        photoLineIndexAtCaret(source, const TextSelection.collapsed(offset: -1)),
        isNull,
      );
    });

    test('follows the extent of a ranged selection', () {
      final NotePhotoLine second = _line(source, 1);

      expect(
        photoLineIndexAtCaret(
          source,
          TextSelection(baseOffset: 0, extentOffset: second.lineStart + 2),
        ),
        1,
      );
    });
  });

  group('insertPhotoLinesAtCaret', () {
    test('a new photo line is the 38-character right medium form', () {
      expect(a, '![](photo/${prefixOf(photoIdA)} "right medium")');
      expect(a.length, 38);
    });

    test('a blank note gains the photo and a fresh line to keep writing on',
        () {
      final TextEditingValue next = insertPhotoLinesAtCaret(
        _value(''),
        <String>[prefixOf(photoIdA)],
      );

      expect(next.text, '$a\n');
      expect(next.selection, caretAt(next.text.length));
      expect(notePhotoLines(next.text), hasLength(1));
    });

    test('mid-line, the photo goes below that line and the caret after it', () {
      final TextEditingValue next = insertPhotoLinesAtCaret(
        _value('one\ntwo', 2),
        <String>[prefixOf(photoIdA)],
      );

      expect(next.text, 'one\n$a\ntwo');
      expect(next.selection, caretAt(next.text.indexOf('two')));
    });

    test('at the end of the last line it appends and opens a new line', () {
      final TextEditingValue next = insertPhotoLinesAtCaret(
        _value('went out'),
        <String>[prefixOf(photoIdA)],
      );

      expect(next.text, 'went out\n$a\n');
      expect(next.selection, caretAt(next.text.length));
    });

    test('at the start of a line the photo goes above it', () {
      final TextEditingValue next = insertPhotoLinesAtCaret(
        _value('one\ntwo', 4),
        <String>[prefixOf(photoIdA)],
      );

      expect(next.text, 'one\n$a\ntwo');
      expect(next.selection, caretAt(next.text.indexOf('two')));
    });

    test('on a blank line the photo takes that line', () {
      final TextEditingValue next = insertPhotoLinesAtCaret(
        _value('one\n\ntwo', 4),
        <String>[prefixOf(photoIdA)],
      );

      expect(next.text, 'one\n$a\ntwo');
    });

    test('with no caret the photo is appended rather than lost', () {
      final TextEditingValue next = insertPhotoLinesAtCaret(
        const TextEditingValue(text: 'one'),
        <String>[prefixOf(photoIdA)],
      );

      expect(next.text, 'one\n$a\n');
    });

    test('several picks land as consecutive photo lines in pick order', () {
      final TextEditingValue next = insertPhotoLinesAtCaret(
        _value('one'),
        <String>[prefixOf(photoIdA), prefixOf(photoIdB)],
      );

      expect(next.text, 'one\n$a\n$b\n');
      expect(
        notePhotoLines(next.text).map((NotePhotoLine line) => line.reference),
        <String>[prefixOf(photoIdA), prefixOf(photoIdB)],
      );
    });

    test('an empty pick leaves the value untouched', () {
      final TextEditingValue value = _value('one', 1);

      expect(insertPhotoLinesAtCaret(value, const <String>[]), same(value));
    });
  });

  group('token rewrites', () {
    final String source = 'before\n$a\nafter';

    test('setPhotoSize rewrites only the title slot', () {
      final TextEditingValue next = setPhotoSize(
        _value(source, 0),
        _line(source),
        PhotoSize.large,
      );

      expect(next.text, 'before\n${photoLine(photoIdA, size: PhotoSize.large)}\nafter');
      expect(_line(next.text).placement.size, PhotoSize.large);
      expect(next.selection, caretAt(0));
    });

    test('setPhotoSide rewrites only the title slot', () {
      final TextEditingValue next = setPhotoSide(
        _value(source, 0),
        _line(source),
        PhotoSide.left,
      );

      expect(_line(next.text).placement.side, PhotoSide.left);
      expect(_line(next.text).placement.size, PhotoSize.medium);
      expect(next.text.startsWith('before\n'), isTrue);
      expect(next.text.endsWith('\nafter'), isTrue);
    });

    test('a caret after the photo shifts by exactly the rewrite length', () {
      final int caret = source.indexOf('after') + 2;
      final TextEditingValue next = setPhotoSize(
        _value(source, caret),
        _line(source),
        PhotoSize.small,
      );

      expect(next.text.substring(next.selection.baseOffset), 'ter');
    });

    test('a caret at the end of the photo line stays at its end', () {
      final NotePhotoLine line = _line(source);
      final TextEditingValue next = setPhotoSize(
        _value(source, line.lineEnd),
        line,
        PhotoSize.full,
      );

      expect(photoLineIndexAtCaret(next.text, next.selection), 0);
      expect(next.selection, caretAt(_line(next.text).lineEnd));
    });

    test('attribute words it does not know are dropped by a rewrite', () {
      final String odd =
          '![](photo/${prefixOf(photoIdA)} "left small nofloat")';
      final TextEditingValue next = setPhotoSize(
        _value(odd, 0),
        _line(odd),
        PhotoSize.large,
      );

      expect(next.text, '![](photo/${prefixOf(photoIdA)} "left large")');
    });

    test('setting a side on an invalid placement writes a valid one', () {
      final String invalid = '![](photo/${prefixOf(photoIdA)} "right huge")';
      final TextEditingValue next = setPhotoSide(
        _value(invalid, 0),
        _line(invalid),
        PhotoSide.left,
      );

      expect(_line(next.text).block.attributes, 'left medium');
      expect(next.text, '![](photo/${prefixOf(photoIdA)} "left medium")');
    });

    test('setPhotoCaption writes the alt slot, sanitised and trimmed', () {
      final TextEditingValue next = setPhotoCaption(
        _value(source, 0),
        _line(source),
        '  the [old] porch\nat dusk  ',
      );

      expect(_line(next.text).caption, 'the [old porch at dusk');
      expect(notePhotoLines(next.text), hasLength(1));
    });

    test('replacePhotoReference swaps the photo and keeps caption and placement',
        () {
      final TextEditingValue next = replacePhotoReference(
        _value(c, 0),
        _line(c),
        prefixOf(photoIdB),
      );

      final NotePhotoLine line = _line(next.text);
      expect(line.reference, prefixOf(photoIdB));
      expect(line.caption, 'porch light');
      expect(line.placement, const PhotoPlacement());
    });

    test('selectPhotoLine puts the caret on that photo', () {
      final String two = '$a\ntext\n$b';
      final TextEditingValue next =
          selectPhotoLine(_value(two, 0), _line(two, 1));

      expect(photoLineIndexAtCaret(next.text, next.selection), 1);
      expect(next.text, two);
    });
  });

  group('move up and move down', () {
    test('moves past the neighbouring line and keeps the blank lines in place',
        () {
      final String source = 'one\n\n$a\n\ntwo';
      final NotePhotoLine line = _line(source);
      final TextEditingValue next =
          movePhotoUp(_value(source, line.lineStart + 3), line);

      expect(next.text, '$a\n\none\n\ntwo');
      expect(photoLineIndexAtCaret(next.text, next.selection), 0);
      expect(next.selection, caretAt(3));
    });

    test('up then down is an exact round trip, caret included', () {
      final String source = 'one\ntwo\n$a\nthree\n\nfour';
      final NotePhotoLine line = _line(source);
      final TextEditingValue start = _value(source, line.lineStart + 7);
      final TextEditingValue up = movePhotoUp(start, line);
      final TextEditingValue back = movePhotoDown(up, _line(up.text));

      expect(up.text, 'one\n$a\ntwo\nthree\n\nfour');
      expect(back, start);
    });

    test('splits a multi-line paragraph one line at a time', () {
      final String source = 'one\ntwo\nthree\n$a';
      final TextEditingValue up =
          movePhotoUp(_value(source), _line(source));

      expect(up.text, 'one\ntwo\n$a\nthree');
    });

    test('steps over a code fence whole instead of falling into it', () {
      final String source = 'para\n```\ncode\n```\n$a';
      final TextEditingValue up =
          movePhotoUp(_value(source), _line(source));

      expect(up.text, 'para\n$a\n```\ncode\n```');
      expect(notePhotoLines(up.text), hasLength(1));
    });

    test('two adjacent photos trade places', () {
      final String source = '$a\n$b';
      final TextEditingValue down =
          movePhotoDown(_value(source, 0), _line(source));

      expect(down.text, '$b\n$a');
      expect(photoLineIndexAtCaret(down.text, down.selection), 1);
    });

    test('the first photo cannot move up and the last cannot move down', () {
      final String source = '$a\nmiddle\n$b';

      expect(canMovePhotoUp(source, _line(source)), isFalse);
      expect(canMovePhotoDown(source, _line(source)), isTrue);
      expect(canMovePhotoUp(source, _line(source, 1)), isTrue);
      expect(canMovePhotoDown(source, _line(source, 1)), isFalse);

      final TextEditingValue value = _value(source, 0);
      expect(movePhotoUp(value, _line(source)), same(value));
      expect(movePhotoDown(value, _line(source, 1)), same(value));
    });
  });

  group('remove and restore', () {
    final List<String> corpus = <String>[
      'one\n$a\ntwo',
      'one\n$a',
      a,
      '$a\n',
      'one\r\n$a',
      'one\r\n$a\r\ntwo\r\n',
      '$a\n$b\n$c',
      '# Title\n\n$a\n\n- item\n$b\n\n```\ncode\n```\n$c',
      '  $a  \nindented',
    ];

    test('the removed text reinserted at its offset is the source, byte for byte',
        () {
      for (final String source in corpus) {
        for (final NotePhotoLine line in notePhotoLines(source)) {
          final PhotoLineRemoval removal =
              removePhotoLine(_value(source, line.lineStart), line);
          final RemovedPhotoLine removed = removal.removed;

          expect(removal.value.text, removed.after, reason: source);
          expect(
            removed.after.replaceRange(
              removed.offset,
              removed.offset,
              removed.text,
            ),
            source,
            reason: source,
          );
          expect(notePhotoLines(removed.after), hasLength(
            notePhotoLines(source).length - 1,
          ), reason: source);
        }
      }
    });

    test('restore gives back the exact value, caret included', () {
      for (final String source in corpus) {
        for (final NotePhotoLine line in notePhotoLines(source)) {
          final TextEditingValue before = _value(source, line.lineEnd);
          final PhotoLineRemoval removal = removePhotoLine(before, line);

          expect(restorePhotoLine(removal.value, removal.removed), before,
              reason: source);
        }
      }
    });

    test('a middle photo takes its own newline with it', () {
      final String source = 'one\n$a\ntwo';
      final PhotoLineRemoval removal =
          removePhotoLine(_value(source, 5), _line(source));

      expect(removal.value.text, 'one\ntwo');
      expect(removal.removed.text, '$a\n');
      expect(removal.value.selection, caretAt(4));
    });

    test('a last photo takes the newline before it, so no blank line is left',
        () {
      final String source = 'one\n$a';
      final PhotoLineRemoval removal =
          removePhotoLine(_value(source), _line(source));

      expect(removal.value.text, 'one');
      expect(removal.removed.text, '\n$a');
    });

    test('after an intervening edit, restore puts the photo back as a line', () {
      final String source = 'one\n$a\ntwo';
      final PhotoLineRemoval removal =
          removePhotoLine(_value(source, 5), _line(source));
      final TextEditingValue edited = _value('${removal.value.text}!');

      final TextEditingValue restored =
          restorePhotoLine(edited, removal.removed);

      expect(restored.text, 'one\n$a\ntwo!');
      expect(notePhotoLines(restored.text), hasLength(1));
    });
  });
}
