import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:field_notes/data/database/app_database.dart' as db;
import 'package:field_notes/data/journal/journal_exceptions.dart';
import 'package:field_notes/data/journal/journal_mappers.dart';
import 'package:field_notes/domain/models/models.dart';

void main() {
  group('toDomainDay', () {
    test('maps a stored mood id to the Mood enum and copies fields', () {
      final row = db.Day(
        id: 'd1',
        date: '2026-07-12',
        moodId: 'calm',
        createdAt: 10,
        updatedAt: 20,
      );

      final day = toDomainDay(row);

      expect(day.id, 'd1');
      expect(day.date, '2026-07-12');
      expect(day.mood, Mood.calm);
      expect(day.createdAt, 10);
      expect(day.updatedAt, 20);
      expect(day.deletedAt, isNull);
    });

    test('maps a null mood id to a null mood', () {
      final row = db.Day(
        id: 'd2',
        date: '2026-07-12',
        createdAt: 0,
        updatedAt: 0,
      );

      expect(toDomainDay(row).mood, isNull);
    });

    test('an unknown mood id reads as a day with no mood', () {
      final row = db.Day(
        id: 'd3',
        date: '2026-07-12',
        moodId: 'euphoric',
        createdAt: 11,
        updatedAt: 22,
      );

      final day = toDomainDay(row);

      expect(day.mood, isNull);
      expect(day.id, 'd3');
      expect(day.date, '2026-07-12');
      expect(day.createdAt, 11);
      expect(day.updatedAt, 22);
    });

    test('an unknown mood id is logged once', () {
      final DebugPrintCallback original = debugPrint;
      final List<String> lines = <String>[];
      debugPrint = (String? message, {int? wrapWidth}) {
        lines.add(message ?? '');
      };
      addTearDown(() => debugPrint = original);

      db.Day row(String id, String moodId) => db.Day(
        id: id,
        date: '2026-07-12',
        moodId: moodId,
        createdAt: 0,
        updatedAt: 0,
      );

      toDomainDay(row('d4', 'loved'));
      toDomainDay(row('d5', 'loved'));
      toDomainDay(row('d6', 'ecstatic'));

      expect(lines, hasLength(2));
      expect(lines.where((String l) => l.contains('"loved"')), hasLength(1));
      expect(lines.where((String l) => l.contains('"ecstatic"')), hasLength(1));
    });
  });

  group('toDomainEntry', () {
    test('maps the stored type string to EntryType and copies fields', () {
      final row = db.Entry(
        id: 'e1',
        dayId: 'd1',
        type: 'voice',
        mediaId: 'm1',
        durationMs: 4200,
        createdAt: 1,
        updatedAt: 2,
      );

      final entry = toDomainEntry(row);

      expect(entry.type, EntryType.voice);
      expect(entry.dayId, 'd1');
      expect(entry.mediaId, 'm1');
      expect(entry.durationMs, 4200);
      expect(entry.textContent, isNull);
    });

    test('throws MalformedRowException on an unknown entry type', () {
      final row = db.Entry(
        id: 'e2',
        dayId: 'd1',
        type: 'hologram',
        createdAt: 0,
        updatedAt: 0,
      );

      expect(() => toDomainEntry(row), throwsA(isA<MalformedRowException>()));
    });
  });

  test('toDomainEntryPhoto copies all fields', () {
    final row = db.EntryPhoto(
      id: 'p1',
      entryId: 'e1',
      mediaId: 'm1',
      sortOrder: 3,
      createdAt: 5,
      updatedAt: 6,
      deletedAt: 7,
    );

    final photo = toDomainEntryPhoto(row);

    expect(photo.id, 'p1');
    expect(photo.entryId, 'e1');
    expect(photo.mediaId, 'm1');
    expect(photo.sortOrder, 3);
    expect(photo.createdAt, 5);
    expect(photo.updatedAt, 6);
    expect(photo.deletedAt, 7);
  });
}
