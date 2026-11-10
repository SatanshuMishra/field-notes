import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/entry_cards/compact/compact_log_card.dart';
import 'package:field_notes/features/entry_cards/compact/log_preview.dart';

import '../support/entry_cards_harness.dart';

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

int _createdAt({required int hour, required int minute}) =>
    DateTime(2026, 1, 1, hour, minute).millisecondsSinceEpoch;

void _useClockFormat(WidgetTester tester, {required bool twentyFourHour}) {
  tester.platformDispatcher.alwaysUse24HourFormatTestValue = twentyFourHour;
  tester.binding.handleMetricsChanged();
  addTearDown(() {
    tester.platformDispatcher.clearAlwaysUse24HourTestValue();
    tester.binding.handleMetricsChanged();
  });
}

Entry _textEntry({
  required String id,
  required String textContent,
  int hour = 9,
  int minute = 0,
}) {
  final int at = _createdAt(hour: hour, minute: minute);
  return Entry(
    id: id,
    dayId: 'd1',
    type: EntryType.text,
    textContent: textContent,
    createdAt: at,
    updatedAt: at,
  );
}

void main() {
  group('logPreviewOf', () {
    test('a short note without photos is not long', () {
      final Entry entry = _textEntry(id: 'e1', textContent: _words(60));

      final LogPreview preview = logPreviewOf(entry);

      expect(preview.isLong, isFalse);
    });

    test(
      'a note with no heading has no title and keeps its first sentence',
      () {
        final String firstSentence = '${_words(99)}.';
        const String secondSentence =
            'Second thoughts arrived after breakfast.';
        final Entry entry = _textEntry(
          id: 'e2',
          textContent: '$firstSentence $secondSentence',
        );

        final LogPreview preview = logPreviewOf(entry);

        expect(preview.title, isEmpty);
        expect(preview.snippet, '$firstSentence $secondSentence');
      },
    );

    test('a long title is cut at 72 characters', () {
      final Entry entry = _textEntry(
        id: 'e2b',
        textContent: '# ${_words(99)}\n\nThe body.',
      );

      final LogPreview preview = logPreviewOf(entry);

      expect(preview.title.length, lessThanOrEqualTo(73));
      expect(preview.title, endsWith('…'));
      expect(preview.snippet, 'The body.');
    });

    test('a saved title stands above the whole note, heading included', () {
      const String paragraph = 'The garden was quiet this morning.';
      final int at = _createdAt(hour: 9, minute: 0);
      final Entry entry = Entry(
        id: 'e2c',
        dayId: 'd1',
        type: EntryType.text,
        title: 'Saved name',
        textContent: '# Lorem ipsum\n\n$paragraph',
        createdAt: at,
        updatedAt: at,
      );

      final LogPreview preview = logPreviewOf(entry);

      expect(preview.title, 'Saved name');
      expect(preview.snippet, 'Lorem ipsum $paragraph');
    });

    test('voice and video logs carry only a title they were given', () {
      final int at = _createdAt(hour: 21, minute: 0);
      Entry media(EntryType type, String? title) => Entry(
        id: 'm-$type-$title',
        dayId: 'd1',
        type: type,
        title: title,
        createdAt: at,
        updatedAt: at,
      );

      expect(logPreviewOf(media(EntryType.video, null)).title, isEmpty);
      expect(logPreviewOf(media(EntryType.voice, '   ')).title, isEmpty);
      expect(logPreviewOf(media(EntryType.video, ' Pier ')).title, 'Pier');
      expect(logPreviewOf(media(EntryType.voice, 'Walk')).title, 'Walk');
    });

    test('a note with a photo is long however short its text', () {
      const String reference = '7f3ac91b2d4e';
      final Entry entry = _textEntry(
        id: 'e3',
        textContent:
            'Hi.\n\n${canonicalPhotoLine(reference, '', const MdPhotoPlacement())}',
      );

      final LogPreview preview = logPreviewOf(entry);

      expect(preview.isLong, isTrue);
      expect(preview.photoCount, 1);
      expect(preview.firstPhotoReference, reference);
    });

    test('a note that opens with a heading leads with the heading', () {
      const String paragraph = 'The garden was quiet this morning.';
      final Entry entry = _textEntry(
        id: 'e4',
        textContent: '# Lorem ipsum\n\n$paragraph',
      );

      final LogPreview preview = logPreviewOf(entry);

      expect(preview.title, 'Lorem ipsum');
      expect(preview.snippet, paragraph);
    });

    test('photo captions never reach the title, the snippet or the word count', () {
      final String caption = List<String>.generate(
        80,
        (int i) => 'caption$i',
      ).join(' ');
      const String reference = '2b8e04d9c1a7';
      final Entry entry = _textEntry(
        id: 'e5',
        textContent:
            'Hi.\n\n${canonicalPhotoLine(reference, caption, const MdPhotoPlacement())}',
      );

      final LogPreview preview = logPreviewOf(entry);

      expect(preview.title, isNot(contains('caption')));
      expect(preview.snippet, isNot(contains('caption')));
      expect(preview.meta, isNot(contains('min read')));
    });

    test('meta joins read time, photo count and video duration', () {
      final String words = List<String>.generate(
        400,
        (int i) => 'w$i',
      ).join(' ');
      const String ref1 = '7f3ac91b2d4e';
      const String ref2 = '2b8e04d9c1a7';
      final Entry note = _textEntry(
        id: 'e6',
        textContent:
            '$words\n\n${canonicalPhotoLine(ref1, '', const MdPhotoPlacement())}'
            '\n\n${canonicalPhotoLine(ref2, '', const MdPhotoPlacement())}',
      );
      final int at = _createdAt(hour: 9, minute: 0);
      final Entry video = Entry(
        id: 'e7',
        dayId: 'd1',
        type: EntryType.video,
        durationMs: 98000,
        createdAt: at,
        updatedAt: at,
      );

      expect(logPreviewOf(note).meta, '2 min read · 2 photos');
      expect(logPreviewOf(video).meta, '1:38');
    });
  });

  testWidgets('card times follow the system 12 or 24 hour setting', (
    WidgetTester tester,
  ) async {
    final Widget cards = MaterialApp(
      home: Scaffold(
        body: Column(
          children: <Widget>[
            for (final Entry entry in <Entry>[
              _textEntry(id: 'e1', textContent: 'Tide.', hour: 9, minute: 30),
              _textEntry(id: 'e2', textContent: 'Moon.', hour: 20, minute: 5),
            ])
              CompactLogCard(
                entry: entry,
                resolver: FakeMediaResolver(),
                density: CompactLogDensity.feed,
                onOpen: () {},
                onDelete: () {},
              ),
          ],
        ),
      ),
    );

    _useClockFormat(tester, twentyFourHour: false);
    await tester.pumpWidget(cards);

    expect(find.text('9:30 AM · morning'), findsOneWidget);
    expect(find.text('8:05 PM · evening'), findsOneWidget);

    _useClockFormat(tester, twentyFourHour: true);
    await tester.pumpWidget(cards);

    expect(find.text('09:30 · morning'), findsOneWidget);
    expect(find.text('20:05 · evening'), findsOneWidget);
  });
}
