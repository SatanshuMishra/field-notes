import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/repositories/journal_repository.dart';
import 'package:field_notes/domain/services/streak_service.dart';
import 'package:field_notes/features/streak/streak_providers.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../state/state_test_support.dart';

Future<void> _seedEntry(JournalRepository repo, String date) async {
  final day = await repo.createDay(date: date);
  await repo.createEntry(dayId: day.id, type: EntryType.text, textContent: date);
}

void main() {
  group('streakSummaryProvider', () {
    test('derives current and longest from live entries under a fixed clock',
        () async {
      final db = newTestDatabase();
      addTearDown(db.close);
      final container = newTestContainer(
        db,
        overrides: [
          streakClockProvider.overrideWithValue(() => DateTime(2026, 7, 15, 9)),
        ],
      );
      final repo = container.read(journalRepositoryProvider);

      await _seedEntry(repo, '2026-07-13');
      await _seedEntry(repo, '2026-07-14');
      await _seedEntry(repo, '2026-07-15');

      final sub = container.listen(
        streakSummaryProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);

      await pumpEventQueue();

      expect(
        container.read(streakSummaryProvider),
        const StreakSummary(current: 3, longest: 3),
      );
    });

    test('resets current when today and yesterday were missed', () async {
      final db = newTestDatabase();
      addTearDown(db.close);
      final container = newTestContainer(
        db,
        overrides: [
          streakClockProvider.overrideWithValue(() => DateTime(2026, 7, 15, 9)),
        ],
      );
      final repo = container.read(journalRepositoryProvider);

      await _seedEntry(repo, '2026-07-10');
      await _seedEntry(repo, '2026-07-11');
      await _seedEntry(repo, '2026-07-12');

      final sub = container.listen(
        streakSummaryProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);

      await pumpEventQueue();

      expect(
        container.read(streakSummaryProvider),
        const StreakSummary(current: 0, longest: 3),
      );
    });

    test('degrades to the empty summary when a stored date is malformed',
        () async {
      final db = newTestDatabase();
      addTearDown(db.close);
      final container = newTestContainer(
        db,
        overrides: [
          streakClockProvider.overrideWithValue(() => DateTime(2026, 7, 15, 9)),
        ],
      );
      final repo = container.read(journalRepositoryProvider);

      await _seedEntry(repo, '2026/07/15');

      final sub = container.listen(
        streakSummaryProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);

      await pumpEventQueue();

      expect(
        () => container.read(streakSummaryProvider),
        returnsNormally,
      );
      expect(
        container.read(streakSummaryProvider),
        const StreakSummary.empty(),
      );
    });
  });
}
