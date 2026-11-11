import 'package:field_notes/data/journal/drift_journal_repository.dart';
import 'package:field_notes/data/sync/change_recorder.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/services/streak_service.dart';
import 'package:field_notes/features/streak/journaled_dates_provider.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../state/state_test_support.dart';

void main() {
  group('journaledDatesProvider', () {
    test('streams only dates with a live entry under a live day', () async {
      final db = newTestDatabase();
      addTearDown(db.close);
      final container = newTestContainer(db);
      final repo = container.read(journalRepositoryProvider);

      final dayA = await repo.createDay(date: '2026-07-15');
      await repo.createEntry(
        dayId: dayA.id,
        type: EntryType.text,
        textContent: 'a',
      );

      await repo.setMoodForDate(date: '2026-07-14', mood: Mood.happy);

      final dayC = await repo.createDay(date: '2026-07-13');
      final goneEntry = await repo.createEntry(
        dayId: dayC.id,
        type: EntryType.text,
        textContent: 'gone',
      );
      await repo.softDeleteEntry(goneEntry.id);

      final dayD = await repo.createDay(date: '2026-07-12');
      await repo.createEntry(
        dayId: dayD.id,
        type: EntryType.text,
        textContent: 'd1',
      );
      await repo.createEntry(
        dayId: dayD.id,
        type: EntryType.text,
        textContent: 'd2',
      );

      final dayE = await repo.createDay(date: '2026-07-11');
      await repo.createEntry(
        dayId: dayE.id,
        type: EntryType.text,
        textContent: 'e',
      );
      await repo.softDeleteDay(dayE.id);

      final sub = container.listen(
        journaledDatesProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);

      await pumpEventQueue();

      final dates =
          container.read(journaledDatesProvider).value ?? const <String>[];
      expect(dates.toSet(), <String>{'2026-07-15', '2026-07-12'});
    });
  });

  group('journalEntryCountsProvider', () {
    test('entry counts count live entries per date', () async {
      final db = newTestDatabase();
      addTearDown(db.close);
      final container = newTestContainer(db);
      final repo = container.read(journalRepositoryProvider);

      final dayA = await repo.createDay(date: '2026-07-15');
      await repo.createEntry(
        dayId: dayA.id,
        type: EntryType.text,
        textContent: 'a1',
      );
      await repo.createEntry(
        dayId: dayA.id,
        type: EntryType.text,
        textContent: 'a2',
      );
      final goneEntry = await repo.createEntry(
        dayId: dayA.id,
        type: EntryType.text,
        textContent: 'gone',
      );
      await repo.softDeleteEntry(goneEntry.id);

      final dayB = await repo.createDay(date: '2026-07-14');
      await repo.createEntry(
        dayId: dayB.id,
        type: EntryType.text,
        textContent: 'b',
      );

      final dayC = await repo.createDay(date: '2026-07-13');
      await repo.createEntry(
        dayId: dayC.id,
        type: EntryType.text,
        textContent: 'c',
      );
      await repo.softDeleteDay(dayC.id);

      final sub = container.listen(
        journalEntryCountsProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);

      await pumpEventQueue();

      expect(container.read(journalEntryCountsProvider).value, <String, int>{
        '2026-07-15': 2,
        '2026-07-14': 1,
      });
    });
  });

  group('streakDaysProvider', () {
    test(
      'lists each live day with logs, its bloom and first log time',
      () async {
        final db = newTestDatabase();
        addTearDown(db.close);
        int now = 1000;
        final container = newTestContainer(db);
        final repo = DriftJournalRepository(
          db,
          recorder: ChangeRecorder(db),
          clock: () => now,
        );

        now = 2000;
        final dayA = await repo.setMoodForDate(
          date: '2026-07-15',
          mood: Mood.happy,
        );
        now = 3000;
        await repo.createEntry(
          dayId: dayA.id,
          type: EntryType.text,
          textContent: 'a1',
        );
        now = 4000;
        await repo.createEntry(
          dayId: dayA.id,
          type: EntryType.text,
          textContent: 'a2',
        );

        now = 5000;
        final dayB = await repo.createDay(date: '2026-07-14');
        final gone = await repo.createEntry(
          dayId: dayB.id,
          type: EntryType.text,
          textContent: 'gone',
        );
        now = 6000;
        await repo.createEntry(
          dayId: dayB.id,
          type: EntryType.text,
          textContent: 'b',
        );
        await repo.softDeleteEntry(gone.id);

        await repo.setMoodForDate(date: '2026-07-13', mood: Mood.calm);

        final sub = container.listen(
          streakDaysProvider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(sub.close);

        await pumpEventQueue();

        expect(container.read(streakDaysProvider).value?.toSet(), <StreakDay>{
          const StreakDay(
            date: '2026-07-15',
            hasBloom: true,
            logCount: 2,
            bloomPickedAt: 2000,
            firstLogAt: 3000,
          ),
          const StreakDay(
            date: '2026-07-14',
            hasBloom: false,
            logCount: 1,
            firstLogAt: 6000,
          ),
        });
      },
    );
  });
}
