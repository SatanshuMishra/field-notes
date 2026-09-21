import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/features/entry_cards/cards/note_body.dart';
import 'package:field_notes/features/entry_cards/cards/note_preview.dart';
import 'package:field_notes/features/entry_cards/notes/note_document.dart';

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
