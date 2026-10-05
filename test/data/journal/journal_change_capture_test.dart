import 'dart:convert';

import 'package:field_notes/data/database/app_database.dart' as db;
import 'package:field_notes/data/journal/drift_journal_repository.dart';
import 'package:field_notes/data/sync/change_recorder.dart';
import 'package:field_notes/data/sync/hlc.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'journal_test_db.dart';

const String _date = '2026-09-29';

void main() {
  late db.AppDatabase database;
  late DriftJournalRepository repository;

  setUp(() {
    database = newTestDatabase();
    repository = DriftJournalRepository(
      database,
      recorder: ChangeRecorder(database),
      idGenerator: sequentialIds(),
      clock: fixedClock(1000),
    );
  });

  tearDown(() async {
    await database.close();
  });

  Future<Set<String>> outbox() async {
    final List<db.SyncOutboxData> rows = await database
        .select(database.syncOutbox)
        .get();
    return rows
        .map((db.SyncOutboxData row) => '${row.recordTable}/${row.rowId}')
        .toSet();
  }

  Future<void> clearOutbox() async {
    await database.delete(database.syncOutbox).go();
  }

  Future<String?> lastClock() async {
    final db.SyncState? row =
        await (database.select(database.syncStates)
              ..where((t) => t.key.equals(ChangeRecorder.lastClockKey)))
            .getSingleOrNull();
    return row?.value;
  }

  test('a failed note save adds no outbox entry', () async {
    int calls = 0;
    final DriftJournalRepository failing = DriftJournalRepository(
      database,
      recorder: ChangeRecorder(database),
      idGenerator: () {
        calls++;
        if (calls > 1) {
          throw StateError('no id for the photo link');
        }
        return 'entry-1';
      },
      clock: fixedClock(1000),
    );

    await expectLater(
      failing.saveNote(
        date: _date,
        source: 'a good day',
        photoMediaIds: const <String>['photo-a'],
      ),
      throwsStateError,
    );

    expect(calls, 2);
    expect(await database.select(database.entries).get(), isEmpty);
    expect(await database.select(database.days).get(), isEmpty);
    expect(await outbox(), isEmpty);
  });

  test('a note save adds one outbox entry per changed record', () async {
    await repository.saveNote(
      date: '2026-09-28',
      source: 'yesterday',
      photoMediaIds: const <String>[],
    );
    await clearOutbox();

    final Entry note = await repository.saveNote(
      date: _date,
      source: 'a good day',
      photoMediaIds: const <String>['photo-a', 'photo-b'],
    );
    final List<EntryPhoto> links = await repository.photosForEntry(note.id);

    expect(await outbox(), <String>{
      'days/day-$_date',
      'entries/${note.id}',
      'entry_photos/${links[0].id}',
      'entry_photos/${links[1].id}',
    });

    await clearOutbox();
    await repository.saveNote(
      entryId: note.id,
      date: _date,
      source: 'a better day',
      photoMediaIds: const <String>['photo-a', 'photo-b'],
    );

    expect(await outbox(), <String>{'entries/${note.id}'});
  });

  test('saving a note keeps the ids of photo links it still uses', () async {
    final Entry note = await repository.saveNote(
      date: _date,
      source: 'three photos',
      photoMediaIds: const <String>['photo-a', 'photo-b'],
    );
    final List<EntryPhoto> first = await repository.photosForEntry(note.id);

    await repository.saveNote(
      entryId: note.id,
      date: _date,
      source: 'three photos',
      photoMediaIds: const <String>['photo-a', 'photo-c'],
    );

    final List<db.EntryPhoto> rows = await database
        .select(database.entryPhotos)
        .get();
    final db.EntryPhoto linkA = rows.singleWhere(
      (db.EntryPhoto row) => row.mediaId == 'photo-a',
    );
    final db.EntryPhoto linkB = rows.singleWhere(
      (db.EntryPhoto row) => row.mediaId == 'photo-b',
    );
    final db.EntryPhoto linkC = rows.singleWhere(
      (db.EntryPhoto row) => row.mediaId == 'photo-c',
    );
    expect(rows, hasLength(3));
    expect(linkA.id, first[0].id);
    expect(linkA.deletedAt, isNull);
    expect(linkB.id, first[1].id);
    expect(linkB.deletedAt, isNotNull);
    expect(<String>{first[0].id, first[1].id}, isNot(contains(linkC.id)));
    expect(linkC.deletedAt, isNull);
    expect(linkC.sortOrder, 1);

    await clearOutbox();
    final String? clockBefore = await lastClock();
    await repository.saveNote(
      entryId: note.id,
      date: _date,
      source: 'three photos',
      photoMediaIds: const <String>['photo-a', 'photo-c'],
    );

    expect(await outbox(), isEmpty);
    expect(await lastClock(), clockBefore);
    expect(await database.select(database.entryPhotos).get(), rows);
  });

  test('two databases give the same date the same day id', () async {
    final db.AppDatabase other = newTestDatabase();
    addTearDown(other.close);
    final DriftJournalRepository otherRepository = DriftJournalRepository(
      other,
      recorder: ChangeRecorder(other),
      idGenerator: sequentialIds('other'),
      clock: fixedClock(2000),
    );

    final Entry here = await repository.saveNote(
      date: _date,
      source: 'from the Mac',
      photoMediaIds: const <String>[],
    );
    final Entry there = await otherRepository.saveNote(
      date: _date,
      source: 'from the phone',
      photoMediaIds: const <String>[],
    );

    expect(here.id, isNot(there.id));
    expect(here.dayId, there.dayId);
    expect((await repository.activeDayForDate(_date))!.id, here.dayId);
    expect((await otherRepository.activeDayForDate(_date))!.id, there.dayId);
  });

  test('a deleted day is revived when its date is used again', () async {
    final Entry first = await repository.saveNote(
      date: _date,
      source: 'before',
      photoMediaIds: const <String>[],
    );
    await repository.setMood(dayId: first.dayId, mood: Mood.calm);
    await repository.softDeleteDay(first.dayId);
    final db.Day deleted = (await database.select(database.days).get()).single;

    final Entry second = await repository.saveNote(
      date: _date,
      source: 'after',
      photoMediaIds: const <String>[],
    );

    final List<db.Day> days = await database.select(database.days).get();
    expect(days, hasLength(1));
    expect(days.single.id, first.dayId);
    expect(days.single.deletedAt, isNull);
    expect(days.single.moodId, isNull);
    expect(second.dayId, first.dayId);
    expect(
      _clockOf(days.single, 'deletedAt') > _clockOf(deleted, 'deletedAt'),
      isTrue,
    );
    expect(await repository.activeDayForDate(_date), isNotNull);
  });
}

Hlc _clockOf(db.Day day, String field) {
  final Map<String, Object?> clocks =
      jsonDecode(day.fieldClocks) as Map<String, Object?>;
  return Hlc.parse(clocks[field]! as String);
}
