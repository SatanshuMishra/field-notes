import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/journal/entries_dao.dart';
import 'package:field_notes/data/sync/change_recorder.dart';
import 'package:field_notes/data/sync/hlc.dart';

import 'journal_test_db.dart';

Future<void> _insertDay(
  AppDatabase db,
  String id,
  String date, {
  int? deletedAt,
}) {
  return db
      .into(db.days)
      .insert(
        DaysCompanion.insert(
          id: id,
          date: date,
          createdAt: 0,
          updatedAt: 0,
          deletedAt: Value(deletedAt),
        ),
      );
}

Future<void> _insertVoice(EntriesDao dao, String id, {List<double>? peaks}) {
  return dao.insertEntry(
    id: id,
    dayId: 'd1',
    type: 'voice',
    textContent: null,
    mediaId: 'blob-$id',
    thumbnailMediaId: null,
    durationMs: 4200,
    createdAt: 1000,
    updatedAt: 1000,
    peaks: peaks,
  );
}

Map<String, Object?> _clocks(Entry row) {
  return jsonDecode(row.fieldClocks) as Map<String, Object?>;
}

void main() {
  late AppDatabase db;
  late EntriesDao dao;

  setUp(() {
    db = newTestDatabase();
    dao = EntriesDao(db, ChangeRecorder(db));
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'insertEntry returns the row and activeEntriesForDay orders by createdAt',
    () async {
      await _insertDay(db, 'd1', '2026-07-12');
      await dao.insertEntry(
        id: 'e2',
        dayId: 'd1',
        type: 'text',
        textContent: 'second',
        mediaId: null,
        thumbnailMediaId: null,
        durationMs: null,
        createdAt: 20,
        updatedAt: 20,
      );
      await dao.insertEntry(
        id: 'e1',
        dayId: 'd1',
        type: 'text',
        textContent: 'first',
        mediaId: null,
        thumbnailMediaId: null,
        durationMs: null,
        createdAt: 10,
        updatedAt: 10,
      );

      final entries = await dao.activeEntriesForDay('d1');

      expect(entries.map((e) => e.id).toList(), ['e1', 'e2']);
    },
  );

  test(
    'updateText replaces the content and softDelete hides the entry',
    () async {
      await _insertDay(db, 'd1', '2026-07-12');
      await dao.insertEntry(
        id: 'e1',
        dayId: 'd1',
        type: 'text',
        textContent: 'draft',
        mediaId: null,
        thumbnailMediaId: null,
        durationMs: null,
        createdAt: 0,
        updatedAt: 0,
      );

      await dao.updateText(id: 'e1', textContent: 'final', updatedAt: 99);
      final updated = await dao.entryById('e1');
      expect(updated!.textContent, 'final');
      expect(updated.updatedAt, 99);

      await dao.softDelete(id: 'e1', deletedAt: 500);
      expect(await dao.activeEntriesForDay('d1'), isEmpty);
      expect((await dao.entryById('e1'))!.deletedAt, 500);
    },
  );

  test('watchActiveEntriesForDate joins days and reacts to inserts', () async {
    await _insertDay(db, 'd1', '2026-07-12');

    final emissions = <List<String>>[];
    final sub = dao
        .watchActiveEntriesForDate('2026-07-12')
        .listen((rows) => emissions.add(rows.map((e) => e.id).toList()));

    await dao.insertEntry(
      id: 'e1',
      dayId: 'd1',
      type: 'text',
      textContent: 'hello',
      mediaId: null,
      thumbnailMediaId: null,
      durationMs: null,
      createdAt: 0,
      updatedAt: 0,
    );
    await pumpEventQueue();

    expect(emissions.last, ['e1']);
    await sub.cancel();
  });

  test(
    'watchActiveEntriesForDate excludes entries of a soft-deleted day',
    () async {
      await _insertDay(db, 'd1', '2026-07-12', deletedAt: 1);
      await dao.insertEntry(
        id: 'e1',
        dayId: 'd1',
        type: 'text',
        textContent: 'orphan',
        mediaId: null,
        thumbnailMediaId: null,
        durationMs: null,
        createdAt: 0,
        updatedAt: 0,
      );

      final rows = await dao.watchActiveEntriesForDate('2026-07-12').first;

      expect(rows, isEmpty);
    },
  );

  test('insertEntry stores peaks as a JSON array and none as null', () async {
    await _insertDay(db, 'd1', '2026-07-12');
    await _insertVoice(dao, 'e1', peaks: <double>[0.1, 0.9]);
    await _insertVoice(dao, 'e2');

    expect((await dao.entryById('e1'))!.peaks, '[0.1,0.9]');
    expect((await dao.entryById('e2'))!.peaks, isNull);
    expect(_clocks((await dao.entryById('e1'))!), contains('peaks'));
  });

  test('saving peaks stamps only the peaks clock', () async {
    await _insertDay(db, 'd1', '2026-07-12');
    await _insertVoice(dao, 'e1');
    final Entry before = (await dao.entryById('e1'))!;
    await db.delete(db.syncOutbox).go();

    await dao.setVoicePeaks(id: 'e1', peaks: <double>[0.25, 0.75]);

    final Entry after = (await dao.entryById('e1'))!;
    final Map<String, Object?> clocksBefore = _clocks(before);
    final Map<String, Object?> clocksAfter = _clocks(after);
    expect(after.peaks, '[0.25,0.75]');
    expect(after.updatedAt, 1000);
    expect(after.textVersion, before.textVersion);
    expect(
      Hlc.parse(clocksAfter['peaks']! as String) >
          Hlc.parse(clocksBefore['peaks']! as String),
      isTrue,
    );
    expect(
      Map<String, Object?>.of(clocksAfter)..remove('peaks'),
      Map<String, Object?>.of(clocksBefore)..remove('peaks'),
    );
    final List<SyncOutboxData> outbox = await db.select(db.syncOutbox).get();
    expect(outbox, hasLength(1));
    expect(outbox.single.recordTable, 'entries');
    expect(outbox.single.rowId, 'e1');
  });

  test('saving the peaks an entry already holds records no change', () async {
    await _insertDay(db, 'd1', '2026-07-12');
    await _insertVoice(dao, 'e1', peaks: <double>[0.25, 0.75]);
    final Entry before = (await dao.entryById('e1'))!;
    await db.delete(db.syncOutbox).go();

    await dao.setVoicePeaks(id: 'e1', peaks: <double>[0.25, 0.75]);

    expect(await dao.entryById('e1'), before);
    expect(await db.select(db.syncOutbox).get(), isEmpty);
  });
}
