import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/domain/notes/notes.dart';
import 'package:field_notes/features/entry_cards/cards/note_body.dart';
import 'package:field_notes/features/entry_cards/cards/note_preview.dart';
import 'package:field_notes/features/entry_cards/notes/note_document.dart';
import 'package:field_notes/features/notes/model/photo_placement.dart';

const Size _surface = Size(1200, 800);

Widget _harness(Widget child, {double width = 360}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: SingleChildScrollView(child: child),
        ),
      ),
    ),
  );
}

String _words(int characters) {
  final StringBuffer buffer = StringBuffer();
  int word = 0;
  while (buffer.length < characters) {
    if (buffer.isNotEmpty) {
      buffer.write(' ');
    }
    buffer.write('word${word++}');
  }
  return buffer.toString().substring(0, characters);
}

const List<String> _photoReferences = <String>[
  '7f3ac91b2d4e',
  '2b8e04d9c1a7',
  'c05f3e6a9d12',
];

const List<String> _paragraphs = <String>[
  'We took the long road down to the lake this morning.',
  'The dock was still wet with dew when we got there.',
  'Lunch was sandwiches on the rocks, out of the wind.',
  'We drove home with the windows down and no radio.',
];

String _photoLineAt(int index) =>
    photoLineFor(reference: _photoReferences[index]);

String _threePhotoNote() => <String>[
      _paragraphs[0],
      _photoLineAt(0),
      _paragraphs[1],
      _photoLineAt(1),
      _paragraphs[2],
      _photoLineAt(2),
      _paragraphs[3],
    ].join('\n\n');

void main() {
  group('notePreviewOf', () {
    test('leaves a note below the limit untouched', () {
      const String source = 'a quiet morning';

      final NotePreviewText preview = notePreviewOf(source);

      expect(preview.text, source);
      expect(preview.wasTruncated, isFalse);
    });

    test('leaves a note exactly at the limit untouched', () {
      final String source = _words(notePreviewCharLimit);
      expect(source.length, notePreviewCharLimit);

      final NotePreviewText preview = notePreviewOf(source);

      expect(preview.text, source);
      expect(preview.wasTruncated, isFalse);
    });

    test('truncates a note one character past the limit', () {
      final String source = _words(notePreviewCharLimit + 1);

      final NotePreviewText preview = notePreviewOf(source);

      expect(preview.wasTruncated, isTrue);
      expect(preview.text.length, lessThanOrEqualTo(notePreviewCharLimit));
      expect(source.startsWith(preview.text), isTrue);
    });

    test('cuts a long note on a word boundary', () {
      final String source = _words(notePreviewCharLimit * 3);

      final NotePreviewText preview = notePreviewOf(source);

      expect(preview.wasTruncated, isTrue);
      expect(preview.text.length, lessThanOrEqualTo(notePreviewCharLimit));
      expect(preview.text.trimRight(), preview.text);
      expect(source[preview.text.length], ' ');
    });

    test('falls back to a hard cut when the head has no break', () {
      final String source = 'x' * (notePreviewCharLimit + 40);

      final NotePreviewText preview = notePreviewOf(source);

      expect(preview.wasTruncated, isTrue);
      expect(preview.text.length, notePreviewCharLimit);
    });

    test('honours an explicit limit', () {
      final NotePreviewText preview =
          notePreviewOf('one two three four', limit: 8);

      expect(preview.wasTruncated, isTrue);
      expect(preview.text, 'one two');
    });

    test('never cuts a surrogate pair in half', () {
      const String pair = '\u{1F331}';
      final String source = '${'x' * 9}$pair${'x' * 40}';

      final NotePreviewText preview = notePreviewOf(source, limit: 10);

      expect(preview.wasTruncated, isTrue);
      expect(preview.text, 'x' * 9);
    });

    test('a preview keeps only the first photo line', () {
      final String source = _threePhotoNote();
      expect(source.length, lessThan(notePreviewCharLimit));

      final NotePreviewText preview = notePreviewOf(source);

      expect(_photoLineAt(0).allMatches(preview.text), hasLength(1));
      expect(preview.text, isNot(contains(_photoReferences[1])));
      expect(preview.text, isNot(contains(_photoReferences[2])));
      for (final String paragraph in _paragraphs) {
        expect(preview.text, contains(paragraph));
      }
      expect(preview.wasTruncated, isTrue);
    });

    test('a preview never cuts inside a photo line', () {
      final String photo = _photoLineAt(0);
      final String source =
          '${_paragraphs[0]}\n\n$photo\n\n${_paragraphs[1]} ${_paragraphs[2]}';
      final int photoStart = source.indexOf(photo);
      final int space = source.indexOf(' ', photoStart);
      final int close = photoStart + photo.length - 1;
      expect(source[close], ')');
      final int limit = (space + close) ~/ 2;
      expect(limit, greaterThan(space));
      expect(limit, lessThan(close));

      final NotePreviewText preview = notePreviewOf(source, limit: limit);

      expect(preview.text, isNot(contains('](photo/')));
      expect(preview.text, _paragraphs[0].trimRight());
      expect(preview.wasTruncated, isTrue);
    });

    test('a note that opens with a photo past the limit previews it whole', () {
      final String photo = photoLineFor(
        reference: _photoReferences[0],
        caption: 'the porch at dusk, ' * 4,
      );
      final String source = '$photo\n\nsome prose after it.';

      final NotePreviewText preview = notePreviewOf(source, limit: 30);

      expect(preview.text, photo);
      expect(preview.wasTruncated, isTrue);
    });

    test('prose that cannot break before the limit ends on the block before',
        () {
      final NotePreviewText preview =
          notePreviewOf('aaa\n\nbbbbbbbbbbbbbb', limit: 10);

      expect(preview.text, 'aaa');
      expect(preview.wasTruncated, isTrue);
    });

    test('dropping a later photo keeps the blocks around it apart', () {
      final String source = <String>[
        _paragraphs[0],
        _photoLineAt(0),
        _paragraphs[1],
        _photoLineAt(1),
        _paragraphs[2],
      ].join('\n');

      final NotePreviewText preview = notePreviewOf(source);

      expect(preview.text, isNot(contains(_photoReferences[1])));
      expect(parseNote(preview.text).whereType<ParagraphBlock>(), hasLength(3));
      expect(preview.wasTruncated, isTrue);
    });

    test('a photo straight after the kept photo ends the preview', () {
      final String source = <String>[
        _photoLineAt(0),
        _photoLineAt(1),
        _paragraphs[0],
      ].join('\n');

      final NotePreviewText preview = notePreviewOf(source);

      expect(preview.text, _photoLineAt(0));
      expect(preview.wasTruncated, isTrue);
    });

    test('a photo that fits keeps its place even when its blank lines do not',
        () {
      final String photo = _photoLineAt(0);
      final String source = 'ab\n\n$photo\n\nzz';

      final NotePreviewText preview =
          notePreviewOf(source, limit: 4 + photo.length);

      expect(preview.text, 'ab\n\n$photo');
      expect(preview.wasTruncated, isTrue);
    });
  });

  group('NotePreview', () {
    testWidgets('renders a short note in full with no Read more', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _harness(const NotePreview(text: 'a quiet morning')),
      );

      expect(find.byType(NoteBody), findsOneWidget);
      expect(find.text('a quiet morning'), findsOneWidget);
      expect(find.text(noteReadMoreLabel), findsNothing);
      expect(find.byType(ShaderMask), findsNothing);
    });

    testWidgets('fades a truncated note and offers Read more', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = _surface;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final String source = _words(notePreviewCharLimit * 2);

      await tester.pumpWidget(_harness(NotePreview(text: source)));

      expect(find.byType(NoteDocument), findsOneWidget);
      expect(find.byType(ShaderMask), findsOneWidget);
      expect(find.text(noteReadMoreLabel), findsOneWidget);

      final NoteDocument document =
          tester.widget<NoteDocument>(find.byType(NoteDocument));
      expect(document.source.length, lessThanOrEqualTo(notePreviewCharLimit));
      expect(source.startsWith(document.source), isTrue);
    });

    testWidgets('lets a tap on the note text reach the surrounding card', (
      WidgetTester tester,
    ) async {
      int taps = 0;

      await tester.pumpWidget(
        _harness(
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => taps++,
            child: const NotePreview(text: 'a quiet morning'),
          ),
        ),
      );

      await tester.tapAt(tester.getCenter(find.text('a quiet morning')));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('Read more fires its callback', (WidgetTester tester) async {
      tester.view.physicalSize = _surface;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      int taps = 0;

      await tester.pumpWidget(
        _harness(
          NotePreview(
            text: _words(notePreviewCharLimit * 2),
            onReadMore: () => taps++,
          ),
        ),
      );

      await tester.tap(find.text(noteReadMoreLabel));
      expect(taps, 1);
    });

    test('the fade covers a fixed band at the bottom, whatever the height', () {
      expect(
        notePreviewFadeStart(400),
        closeTo(1 - notePreviewFadeHeight / 400, 1e-9),
      );
      expect(
        notePreviewFadeStart(1000),
        closeTo(1 - notePreviewFadeHeight / 1000, 1e-9),
      );
      expect(notePreviewFadeStart(notePreviewFadeHeight), 0);
      expect(notePreviewFadeStart(10), 0);
    });
  });
}
