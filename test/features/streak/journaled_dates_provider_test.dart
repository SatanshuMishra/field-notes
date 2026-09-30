import 'package:field_notes/domain/models/models.dart';
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
}
