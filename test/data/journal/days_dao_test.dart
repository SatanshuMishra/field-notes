import 'package:flutter_test/flutter_test.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/journal/days_dao.dart';

import 'journal_test_db.dart';

void main() {
  late AppDatabase db;
  late DaysDao dao;

  setUp(() {
    db = newTestDatabase();
    dao = DaysDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('insertDay returns the stored row and dayById reads it back', () async {
    final inserted = await dao.insertDay(
      id: 'd1',
      date: '2026-07-12',
      moodId: 'calm',
      createdAt: 10,
      updatedAt: 10,
    );

    expect(inserted.id, 'd1');
    expect(inserted.moodId, 'calm');
    expect(await dao.dayById('d1'), inserted);
  });

  test('activeDayForDate ignores soft-deleted rows', () async {
    await dao.insertDay(
      id: 'd1',
      date: '2026-07-12',
      moodId: null,
      createdAt: 0,
      updatedAt: 0,
    );
    await dao.softDelete(id: 'd1', deletedAt: 5);

    expect(await dao.activeDayForDate('2026-07-12'), isNull);
    final raw = await dao.dayById('d1');
    expect(raw!.deletedAt, 5);
    expect(raw.updatedAt, 5);
  });

  test('updateMood sets and clears the mood id', () async {
    await dao.insertDay(
      id: 'd1',
      date: '2026-07-12',
      moodId: 'happy',
      createdAt: 0,
      updatedAt: 0,
    );

    await dao.updateMood(id: 'd1', moodId: 'sad', updatedAt: 100);
    expect((await dao.dayById('d1'))!.moodId, 'sad');

    await dao.updateMood(id: 'd1', moodId: null, updatedAt: 200);
    final cleared = await dao.dayById('d1');
    expect(cleared!.moodId, isNull);
    expect(cleared.updatedAt, 200);
  });

  test('watchActiveDaysInMonth returns matching active days ascending', () async {
    await dao.insertDay(id: 'a', date: '2026-07-20', moodId: null, createdAt: 0, updatedAt: 0);
    await dao.insertDay(id: 'b', date: '2026-07-01', moodId: null, createdAt: 0, updatedAt: 0);
    await dao.insertDay(id: 'c', date: '2026-08-01', moodId: null, createdAt: 0, updatedAt: 0);

    final days = await dao.watchActiveDaysInMonth('2026-07-').first;

    expect(days.map((d) => d.id).toList(), ['b', 'a']);
  });

  test('watchAllActiveDays returns active days newest first', () async {
    await dao.insertDay(id: 'a', date: '2026-07-01', moodId: null, createdAt: 0, updatedAt: 0);
    await dao.insertDay(id: 'b', date: '2026-07-20', moodId: null, createdAt: 0, updatedAt: 0);

    final days = await dao.watchAllActiveDays().first;

    expect(days.map((d) => d.id).toList(), ['b', 'a']);
  });

  test('activeDaysOnMonthDay matches the month-day across years newest first',
      () async {
    await dao.insertDay(id: 'a', date: '2024-07-12', moodId: null, createdAt: 0, updatedAt: 0);
    await dao.insertDay(id: 'b', date: '2025-07-12', moodId: null, createdAt: 0, updatedAt: 0);
    await dao.insertDay(id: 'c', date: '2025-07-13', moodId: null, createdAt: 0, updatedAt: 0);

    final days = await dao.activeDaysOnMonthDay('-07-12');

    expect(days.map((d) => d.id).toList(), ['b', 'a']);
  });
}
