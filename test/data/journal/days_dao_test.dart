import 'package:flutter_test/flutter_test.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/journal/days_dao.dart';
import 'package:field_notes/data/sync/change_recorder.dart';

import 'journal_test_db.dart';

void main() {
  late AppDatabase db;
  late DaysDao dao;

  setUp(() {
    db = newTestDatabase();
    dao = DaysDao(db, ChangeRecorder(db));
  });

  tearDown(() async {
    await db.close();
  });

  Future<Day> insert(String date, {String? moodId, int at = 0}) {
    return dao.insertDay(
      date: date,
      moodId: moodId,
      createdAt: at,
      updatedAt: at,
    );
  }

  test('insertDay returns the stored row and dayById reads it back', () async {
    final inserted = await insert('2026-07-12', moodId: 'calm', at: 10);

    expect(inserted.id, 'day-2026-07-12');
    expect(inserted.moodId, 'calm');
    expect(await dao.dayById('day-2026-07-12'), inserted);
  });

  test('activeDayForDate ignores soft-deleted rows', () async {
    await insert('2026-07-12');
    await dao.softDelete(id: 'day-2026-07-12', deletedAt: 5);

    expect(await dao.activeDayForDate('2026-07-12'), isNull);
    final raw = await dao.dayById('day-2026-07-12');
    expect(raw!.deletedAt, 5);
    expect(raw.updatedAt, 5);
  });

  test('updateMood sets and clears the mood id', () async {
    await insert('2026-07-12', moodId: 'happy');

    await dao.updateMood(id: 'day-2026-07-12', moodId: 'sad', updatedAt: 100);
    expect((await dao.dayById('day-2026-07-12'))!.moodId, 'sad');

    await dao.updateMood(id: 'day-2026-07-12', moodId: null, updatedAt: 200);
    final cleared = await dao.dayById('day-2026-07-12');
    expect(cleared!.moodId, isNull);
    expect(cleared.updatedAt, 200);
  });

  test(
    'watchActiveDaysInMonth returns matching active days ascending',
    () async {
      await insert('2026-07-20');
      await insert('2026-07-01');
      await insert('2026-08-01');

      final days = await dao.watchActiveDaysInMonth('2026-07-').first;

      expect(days.map((d) => d.date).toList(), ['2026-07-01', '2026-07-20']);
    },
  );

  test('watchAllActiveDays returns active days newest first', () async {
    await insert('2026-07-01');
    await insert('2026-07-20');

    final days = await dao.watchAllActiveDays().first;

    expect(days.map((d) => d.date).toList(), ['2026-07-20', '2026-07-01']);
  });

  test(
    'activeDaysOnMonthDay matches the month-day across years newest first',
    () async {
      await insert('2024-07-12');
      await insert('2025-07-12');
      await insert('2025-07-13');

      final days = await dao.activeDaysOnMonthDay('-07-12');

      expect(days.map((d) => d.date).toList(), ['2025-07-12', '2024-07-12']);
    },
  );
}
