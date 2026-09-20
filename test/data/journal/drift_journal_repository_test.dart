import 'package:flutter_test/flutter_test.dart';
import 'package:field_notes/data/database/app_database.dart' show AppDatabase;
import 'package:field_notes/data/journal/drift_journal_repository.dart';
import 'package:field_notes/data/journal/journal_exceptions.dart';
import 'package:field_notes/domain/models/models.dart';

import 'journal_test_db.dart';

void main() {
  late AppDatabase db;
  late DriftJournalRepository repo;
  var idCounter = 0;
  var nowValue = 1000;

  setUp(() {
    idCounter = 0;
    nowValue = 1000;
    db = newTestDatabase();
    repo = DriftJournalRepository(
      db,
      idGenerator: () => 'id-${(idCounter++).toString().padLeft(4, '0')}',
      clock: () => nowValue,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('days', () {
    test('createDay stores an active day mapped to the domain model', () async {
      final day = await repo.createDay(date: '2026-07-12', mood: Mood.calm);

      expect(day.id, 'id-0000');
      expect(day.date, '2026-07-12');
      expect(day.mood, Mood.calm);
      expect(day.createdAt, 1000);
      expect(day.deletedAt, isNull);
      expect(await repo.activeDayForDate('2026-07-12'), day);
    });

    test('createDay rejects a second active day for the same date', () async {
      await repo.createDay(date: '2026-07-12');

      await expectLater(
        repo.createDay(date: '2026-07-12'),
        throwsA(isA<DuplicateDayException>()),
      );
    });

    test('createDay succeeds again after the prior day is soft-deleted',
        () async {
      final first = await repo.createDay(date: '2026-07-12');
      await repo.softDeleteDay(first.id);

      final second = await repo.createDay(date: '2026-07-12');

      expect(second.id, isNot(first.id));
      expect(await repo.activeDayForDate('2026-07-12'), second);
    });

    test('ensureDayForDate is idempotent for the same date', () async {
      final a = await repo.ensureDayForDate('2026-07-12');
      final b = await repo.ensureDayForDate('2026-07-12');

      expect(b.id, a.id);
    });

    test('setMoodForDate creates, updates, then clears the mood', () async {
      final created =
          await repo.setMoodForDate(date: '2026-07-12', mood: Mood.happy);
      expect(created.mood, Mood.happy);

      nowValue = 2000;
      final updated =
          await repo.setMoodForDate(date: '2026-07-12', mood: Mood.sad);
      expect(updated.id, created.id);
      expect(updated.mood, Mood.sad);
      expect(updated.updatedAt, 2000);

      final cleared =
          await repo.setMoodForDate(date: '2026-07-12', mood: null);
      expect(cleared.mood, isNull);
    });

    test('setMood updates the mood on an existing day by id', () async {
      final day = await repo.createDay(date: '2026-07-12');

      await repo.setMood(dayId: day.id, mood: Mood.warm);

      expect((await repo.dayById(day.id))!.mood, Mood.warm);
    });

    test('softDeleteDay hides the day from active lookups', () async {
      final day = await repo.createDay(date: '2026-07-12');

      await repo.softDeleteDay(day.id);

      expect(await repo.activeDayForDate('2026-07-12'), isNull);
      expect((await repo.dayById(day.id))!.isDeleted, isTrue);
    });
  });

  group('entries', () {
    test('createEntry and entriesForDay return active entries in created order',
        () async {
      final day = await repo.ensureDayForDate('2026-07-12');
      nowValue = 10;
      final first = await repo.createEntry(
        dayId: day.id,
        type: EntryType.text,
        textContent: 'one',
      );
      nowValue = 20;
      final second = await repo.createEntry(
        dayId: day.id,
        type: EntryType.text,
        textContent: 'two',
      );

      final entries = await repo.entriesForDay(day.id);

      expect(entries.map((e) => e.id).toList(), [first.id, second.id]);
      expect(entries.first.textContent, 'one');
    });

    test('updateEntryText replaces the text and bumps updatedAt', () async {
      final day = await repo.ensureDayForDate('2026-07-12');
      final entry = await repo.createEntry(
        dayId: day.id,
        type: EntryType.text,
        textContent: 'draft',
      );

      nowValue = 5000;
      await repo.updateEntryText(id: entry.id, textContent: 'final');

      final refreshed = await repo.entryById(entry.id);
      expect(refreshed!.textContent, 'final');
      expect(refreshed.updatedAt, 5000);
    });

    test('softDeleteEntry removes it from entriesForDay', () async {
      final day = await repo.ensureDayForDate('2026-07-12');
      final entry = await repo.createEntry(
        dayId: day.id,
        type: EntryType.text,
        textContent: 'x',
      );

      await repo.softDeleteEntry(entry.id);

      expect(await repo.entriesForDay(day.id), isEmpty);
    });
  });

  group('entry photos', () {
    test('addPhoto orders by sortOrder and softDeletePhoto filters deletes',
        () async {
      final day = await repo.ensureDayForDate('2026-07-12');
      final entry = await repo.createEntry(
        dayId: day.id,
        type: EntryType.text,
        textContent: 'x',
      );
      await seedMediaBlob(db, 'blob-a');
      await seedMediaBlob(db, 'blob-b');
      final p2 =
          await repo.addPhoto(entryId: entry.id, mediaId: 'blob-b', sortOrder: 2);
      final p1 =
          await repo.addPhoto(entryId: entry.id, mediaId: 'blob-a', sortOrder: 1);

      expect(
        (await repo.photosForEntry(entry.id)).map((p) => p.id).toList(),
        [p1.id, p2.id],
      );

      await repo.softDeletePhoto(p1.id);

      expect((await repo.photosForEntry(entry.id)).single.id, p2.id);
    });
  });

  group('reactive queries', () {
    test('watchEntriesForDate emits the today feed and updates on new entries',
        () async {
      final day = await repo.ensureDayForDate('2026-07-12');

      final emissions = <List<Entry>>[];
      final sub = repo.watchEntriesForDate('2026-07-12').listen(emissions.add);

      await repo.createEntry(
        dayId: day.id,
        type: EntryType.text,
        textContent: 'hello',
      );
      await pumpEventQueue();

      expect(emissions.last.single.textContent, 'hello');
      await sub.cancel();
    });

    test('watchDaysInMonth returns active days for the month ascending',
        () async {
      await repo.createDay(date: '2026-07-01', mood: Mood.happy);
      await repo.createDay(date: '2026-07-20', mood: Mood.calm);
      await repo.createDay(date: '2026-08-05');

      final days = await repo.watchDaysInMonth(year: 2026, month: 7).first;

      expect(days.map((d) => d.date).toList(), ['2026-07-01', '2026-07-20']);
    });

    test('watchAllDays lists active days newest first', () async {
      await repo.createDay(date: '2026-07-01');
      await repo.createDay(date: '2026-07-20');

      final days = await repo.watchAllDays().first;

      expect(days.map((d) => d.date).toList(), ['2026-07-20', '2026-07-01']);
    });

    test('watchDayForDate emits the current mood-bearing day', () async {
      await repo.setMoodForDate(date: '2026-07-12', mood: Mood.hopeful);

      final day = await repo.watchDayForDate('2026-07-12').first;

      expect(day!.mood, Mood.hopeful);
    });
  });

  test('onThisDay returns matching month-day across years newest first',
      () async {
    await repo.createDay(date: '2024-07-12');
    await repo.createDay(date: '2025-07-12');
    await repo.createDay(date: '2025-07-13');

    final matches = await repo.onThisDay(month: 7, day: 12);

    expect(matches.map((d) => d.date).toList(), ['2025-07-12', '2024-07-12']);
  });

  group('saveNote', () {
    test('creates the day and a text entry when no entry id is given',
        () async {
      await seedMediaBlob(db, 'blob-a');
      await seedMediaBlob(db, 'blob-b');

      final entry = await repo.saveNote(
        date: '2026-07-12',
        source: 'a good day',
        photoMediaIds: ['blob-b', 'blob-a'],
      );

      final day = await repo.activeDayForDate('2026-07-12');
      expect(day, isNotNull);
      expect(entry.dayId, day!.id);
      expect(entry.type, EntryType.text);
      expect(entry.textContent, 'a good day');
      expect(entry.createdAt, 1000);
      expect(await repo.entriesForDay(day.id), [entry]);
      final photos = await repo.photosForEntry(entry.id);
      expect(photos.map((p) => p.mediaId).toList(), ['blob-b', 'blob-a']);
      expect(photos.map((p) => p.sortOrder).toList(), [0, 1]);
    });

    test('reuses an existing active day for the date', () async {
      final day = await repo.setMoodForDate(date: '2026-07-12', mood: Mood.calm);

      final entry = await repo.saveNote(
        date: '2026-07-12',
        source: 'a good day',
        photoMediaIds: const [],
      );

      expect(entry.dayId, day.id);
      expect((await repo.activeDayForDate('2026-07-12'))!.mood, Mood.calm);
    });

    test('updates the text and rewrites the photo index for a supplied id',
        () async {
      await seedMediaBlob(db, 'blob-a');
      await seedMediaBlob(db, 'blob-b');
      final created = await repo.saveNote(
        date: '2026-07-12',
        source: 'a good day',
        photoMediaIds: ['blob-a'],
      );
      nowValue = 2000;

      final edited = await repo.saveNote(
        entryId: created.id,
        date: '2026-07-12',
        source: 'a better day',
        photoMediaIds: ['blob-b'],
      );

      expect(edited.id, created.id);
      expect(edited.dayId, created.dayId);
      expect(edited.textContent, 'a better day');
      expect(edited.createdAt, 1000);
      expect(edited.updatedAt, 2000);
      final photos = await repo.photosForEntry(created.id);
      expect(photos.map((p) => p.mediaId).toList(), ['blob-b']);
      final rows = await db.select(db.entryPhotos).get();
      expect(rows, hasLength(1));
    });

    test('rejects an unknown entry id without touching the tables', () async {
      await expectLater(
        repo.saveNote(
          entryId: 'missing',
          date: '2026-07-12',
          source: 'a good day',
          photoMediaIds: const [],
        ),
        throwsA(isA<StateError>()),
      );
      expect(await db.select(db.entries).get(), isEmpty);
    });

    test('entry and entry_photos land or roll back together', () async {
      await expectLater(
        repo.saveNote(
          date: '2026-07-12',
          source: 'a good day',
          photoMediaIds: ['blob-that-does-not-exist'],
        ),
        throwsA(anything),
      );

      expect(await repo.activeDayForDate('2026-07-12'), isNull);
      expect(await db.select(db.entries).get(), isEmpty);
      expect(await db.select(db.entryPhotos).get(), isEmpty);
    });

    test('a failed edit leaves the previous text and photos in place',
        () async {
      await seedMediaBlob(db, 'blob-a');
      final created = await repo.saveNote(
        date: '2026-07-12',
        source: 'a good day',
        photoMediaIds: ['blob-a'],
      );

      await expectLater(
        repo.saveNote(
          entryId: created.id,
          date: '2026-07-12',
          source: 'a worse day',
          photoMediaIds: ['blob-that-does-not-exist'],
        ),
        throwsA(anything),
      );

      expect((await repo.entryById(created.id))!.textContent, 'a good day');
      final photos = await repo.photosForEntry(created.id);
      expect(photos.map((p) => p.mediaId).toList(), ['blob-a']);
    });
  });
}
