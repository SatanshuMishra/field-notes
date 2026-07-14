import 'package:field_notes/data/database/app_database.dart' show MediaBlobsCompanion;
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter_test/flutter_test.dart';

import 'state_test_support.dart';

void main() {
  group('journal stream providers', () {
    test('dayForDate emits null then the created day', () async {
      final db = newTestDatabase();
      addTearDown(db.close);
      final container = newTestContainer(db);
      final repo = container.read(journalRepositoryProvider);

      final sub = container.listen(
        dayForDateProvider('2026-07-14'),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);

      await pumpEventQueue();
      expect(container.read(dayForDateProvider('2026-07-14')).value, isNull);

      await repo.createDay(date: '2026-07-14', mood: Mood.happy);
      await pumpEventQueue();

      final day = container.read(dayForDateProvider('2026-07-14')).value;
      expect(day?.date, '2026-07-14');
      expect(day?.mood, Mood.happy);
    });

    test('allDays emits every active day', () async {
      final db = newTestDatabase();
      addTearDown(db.close);
      final container = newTestContainer(db);
      final repo = container.read(journalRepositoryProvider);

      final sub = container.listen(allDaysProvider, (_, _) {},
          fireImmediately: true);
      addTearDown(sub.close);

      await repo.createDay(date: '2026-07-13');
      await repo.createDay(date: '2026-07-14');
      await pumpEventQueue();

      final days = container.read(allDaysProvider).value ?? const <Day>[];
      expect(days.map((d) => d.date).toSet(), {'2026-07-13', '2026-07-14'});
    });

    test('daysInMonth is scoped to the requested year and month', () async {
      final db = newTestDatabase();
      addTearDown(db.close);
      final container = newTestContainer(db);
      final repo = container.read(journalRepositoryProvider);

      final sub = container.listen(
        daysInMonthProvider(year: 2026, month: 7),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);

      await repo.createDay(date: '2026-07-14');
      await repo.createDay(date: '2026-08-01');
      await pumpEventQueue();

      final days = container
              .read(daysInMonthProvider(year: 2026, month: 7))
              .value ??
          const <Day>[];
      expect(days.map((d) => d.date), ['2026-07-14']);
    });

    test('entriesForDay and photosForEntry track their parent', () async {
      final db = newTestDatabase();
      addTearDown(db.close);
      final container = newTestContainer(db);
      final repo = container.read(journalRepositoryProvider);

      final day = await repo.createDay(date: '2026-07-14');
      final entry = await repo.createEntry(
        dayId: day.id,
        type: EntryType.text,
        textContent: 'hello',
      );
      await db.into(db.mediaBlobs).insert(
            MediaBlobsCompanion.insert(
              id: 'a' * 64,
              relPath: 'blobs/aa/${'a' * 62}',
              mime: 'image/png',
              kind: 'photo',
              bytes: 4,
              createdAt: 0,
            ),
          );

      final entriesSub = container.listen(
        entriesForDayProvider(day.id),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(entriesSub.close);
      final photosSub = container.listen(
        photosForEntryProvider(entry.id),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(photosSub.close);

      await pumpEventQueue();
      final entries =
          container.read(entriesForDayProvider(day.id)).value ??
              const <Entry>[];
      expect(entries.single.textContent, 'hello');

      await repo.addPhoto(entryId: entry.id, mediaId: 'a' * 64, sortOrder: 0);
      await pumpEventQueue();
      final photos =
          container.read(photosForEntryProvider(entry.id)).value ??
              const <EntryPhoto>[];
      expect(photos.single.mediaId, 'a' * 64);
    });
  });
}
