import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/today/today_memory.dart';
import 'package:flutter_test/flutter_test.dart';

Day _day({required String date, Mood? mood, int? deletedAt}) => Day(
      id: 'day-$date',
      date: date,
      mood: mood,
      createdAt: 0,
      updatedAt: 0,
      deletedAt: deletedAt,
    );

Entry _entry({
  required EntryType type,
  String id = 'entry-1',
  String? textContent,
  int? deletedAt,
}) =>
    Entry(
      id: id,
      dayId: 'day-1',
      type: type,
      textContent: textContent,
      createdAt: 0,
      updatedAt: 0,
      deletedAt: deletedAt,
    );

void main() {
  group('selectOnThisDay', () {
    test('picks the most recent prior year', () {
      final OnThisDayMemory? memory = selectOnThisDay(
        candidates: <Day>[
          _day(date: '2022-07-19', mood: Mood.sad),
          _day(date: '2025-07-19', mood: Mood.calm),
          _day(date: '2024-07-19', mood: Mood.happy),
        ],
        today: DateTime(2026, 7, 19, 8),
      );

      expect(memory?.day.date, '2025-07-19');
      expect(memory?.yearsAgo, 1);
    });

    test('ignores today, future dates and tombstoned days', () {
      final OnThisDayMemory? memory = selectOnThisDay(
        candidates: <Day>[
          _day(date: '2026-07-19', mood: Mood.happy),
          _day(date: '2027-07-19', mood: Mood.happy),
          _day(date: '2025-07-19', mood: Mood.happy, deletedAt: 1),
          _day(date: '2023-07-19', mood: Mood.tired),
        ],
        today: DateTime(2026, 7, 19),
      );

      expect(memory?.day.date, '2023-07-19');
      expect(memory?.yearsAgo, 3);
    });

    test('returns null when there is nothing to remember', () {
      expect(
        selectOnThisDay(
          candidates: <Day>[_day(date: '2026-07-19')],
          today: DateTime(2026, 7, 19),
        ),
        isNull,
      );
      expect(
        selectOnThisDay(candidates: const <Day>[], today: DateTime(2026, 7, 19)),
        isNull,
      );
    });
  });

  group('firstTextPreview', () {
    test('collapses whitespace and truncates long notes', () {
      final String long = List<String>.filled(40, 'word').join(' ');
      final String? preview = firstTextPreview(<Entry>[
        _entry(type: EntryType.text, textContent: '  $long  '),
      ]);

      expect(preview, isNotNull);
      expect(preview!.length, memoryPreviewMaxLength + 1);
      expect(preview.endsWith('…'), isTrue);
      expect(preview.contains('  '), isFalse);
    });

    test('uses the first usable text entry only', () {
      expect(
        firstTextPreview(<Entry>[
          _entry(type: EntryType.voice, id: 'a'),
          _entry(type: EntryType.text, id: 'b', textContent: '   '),
          _entry(type: EntryType.text, id: 'c', textContent: 'sun\n on the\tdeck'),
          _entry(type: EntryType.text, id: 'd', textContent: 'later note'),
        ]),
        'sun on the deck',
      );
    });

    test('projects Markdown to prose before collapsing and truncating', () {
      final String longWord = 'x' * 100;
      expect(
        firstTextPreview(<Entry>[
          _entry(
            type: EntryType.text,
            textContent: '# **Head**\n\n![alt](photo/0123456789ab)\n\n- *item*',
          ),
        ]),
        'Head alt item',
      );

      final String? preview = firstTextPreview(<Entry>[
        _entry(type: EntryType.text, textContent: '**$longWord**'),
      ]);
      expect(preview, '${'x' * memoryPreviewMaxLength}…');
    });

    test('truncates on projected length, not source length', () {
      final String prose = 'w' * 85;
      final String? preview = firstTextPreview(<Entry>[
        _entry(type: EntryType.text, textContent: '## **$prose**'),
      ]);

      expect(preview, prose);
      expect(preview!.endsWith('…'), isFalse);
    });

    test('returns null when no usable text entry exists', () {
      expect(firstTextPreview(const <Entry>[]), isNull);
      expect(
        firstTextPreview(<Entry>[
          _entry(type: EntryType.video),
          _entry(type: EntryType.text, textContent: 'gone', deletedAt: 1),
        ]),
        isNull,
      );
    });
  });
}
