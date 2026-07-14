import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/journal/entries_dao.dart';

import 'journal_test_db.dart';

Future<void> _insertDay(
  AppDatabase db,
  String id,
  String date, {
  int? deletedAt,
}) {
  return db.into(db.days).insert(
        DaysCompanion.insert(
          id: id,
          date: date,
          createdAt: 0,
          updatedAt: 0,
          deletedAt: Value(deletedAt),
        ),
      );
}

void main() {
  late AppDatabase db;
  late EntriesDao dao;

  setUp(() {
    db = newTestDatabase();
    dao = EntriesDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('insertEntry returns the row and activeEntriesForDay orders by createdAt',
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
  });

  test('updateText replaces the content and softDelete hides the entry',
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
  });

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

  test('watchActiveEntriesForDate excludes entries of a soft-deleted day',
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
  });
}
