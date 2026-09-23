import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/entry_cards/compact/log_preview.dart';
import 'package:field_notes/features/notes/model/photo_placement.dart';

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

    test('a long note leads with its first sentence cut at 72 characters', () {
      final String firstSentence = '${_words(99)}.';
      const String secondSentence = 'Second thoughts arrived after breakfast.';
      final Entry entry = _textEntry(
        id: 'e2',
        textContent: '$firstSentence $secondSentence',
      );

      final LogPreview preview = logPreviewOf(entry);

      expect(preview.lead.length, lessThanOrEqualTo(73));
      expect(preview.lead, endsWith('…'));
      expect(preview.snippet, startsWith('Second thoughts'));
    });

    test('a note with a photo is long however short its text', () {
      const String reference = '7f3ac91b2d4e';
      final Entry entry = _textEntry(
        id: 'e3',
        textContent: 'Hi.\n\n${photoLineFor(reference: reference)}',
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

      expect(preview.lead, 'Lorem ipsum');
      expect(preview.snippet, paragraph);
    });

    test(
        'photo captions never reach the lead, the snippet or the word count',
        () {
      final String caption =
          List<String>.generate(80, (int i) => 'caption$i').join(' ');
      const String reference = '2b8e04d9c1a7';
      final Entry entry = _textEntry(
        id: 'e5',
        textContent:
            'Hi.\n\n${photoLineFor(reference: reference, caption: caption)}',
      );

      final LogPreview preview = logPreviewOf(entry);

      expect(preview.lead, isNot(contains('caption')));
      expect(preview.snippet, isNot(contains('caption')));
      expect(preview.meta, isNot(contains('min read')));
    });

    test('meta joins read time, photo count and video duration', () {
      final String words =
          List<String>.generate(400, (int i) => 'w$i').join(' ');
      const String ref1 = '7f3ac91b2d4e';
      const String ref2 = '2b8e04d9c1a7';
      final Entry note = _textEntry(
        id: 'e6',
        textContent: '$words\n\n${photoLineFor(reference: ref1)}\n\n'
            '${photoLineFor(reference: ref2)}',
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

    test('the heading names the part of day and the kind of log', () {
      final Entry note =
          _textEntry(id: 'e8', textContent: 'Hi.', hour: 14, minute: 30);
      final int at = _createdAt(hour: 18, minute: 5);
      final Entry voice = Entry(
        id: 'e9',
        dayId: 'd1',
        type: EntryType.voice,
        createdAt: at,
        updatedAt: at,
      );

      expect(logPreviewOf(note).heading, 'Afternoon note');
      expect(logPreviewOf(voice).heading, 'Evening voice log');
    });
  });
}
