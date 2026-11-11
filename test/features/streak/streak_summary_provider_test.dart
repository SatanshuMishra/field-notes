import 'package:field_notes/data/journal/drift_journal_repository.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/services/streak_service.dart';
import 'package:field_notes/features/streak/journaled_dates_provider.dart';
import 'package:field_notes/features/streak/streak_providers.dart';
import 'package:field_notes/state/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../state/state_test_support.dart';

Future<void> _seedEntry(
  ProviderContainer container,
  String date, {
  Mood? mood = Mood.calm,
}) async {
  final int noon = (DateTime.tryParse(date) ?? DateTime(2026, 7, 15))
      .add(const Duration(hours: 12))
      .millisecondsSinceEpoch;
  final DriftJournalRepository repo = DriftJournalRepository(
    container.read(databaseProvider),
    recorder: container.read(changeRecorderProvider),
    clock: () => noon,
  );
  final day = await repo.createDay(date: date, mood: mood);
  await repo.createEntry(
    dayId: day.id,
    type: EntryType.text,
    textContent: date,
  );
}

StreakDay _finished(String date) =>
    StreakDay(date: date, hasBloom: true, logCount: 1);

void main() {
  group('streakSummaryProvider', () {
    test(
      'derives current and longest from live entries under a fixed clock',
      () async {
        final db = newTestDatabase();
        addTearDown(db.close);
        final container = newTestContainer(
          db,
          overrides: [
            streakClockProvider.overrideWithValue(
              () => DateTime(2026, 7, 15, 9),
            ),
          ],
        );

        await _seedEntry(container, '2026-07-13');
        await _seedEntry(container, '2026-07-14');
        await _seedEntry(container, '2026-07-15');

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
      },
    );

    test('a day with logs and no bloom does not count', () async {
      final db = newTestDatabase();
      addTearDown(db.close);
      final container = newTestContainer(
        db,
        overrides: [
          streakClockProvider.overrideWithValue(() => DateTime(2026, 7, 15, 9)),
        ],
      );

      await _seedEntry(container, '2026-07-13');
      await _seedEntry(container, '2026-07-14', mood: null);
      await _seedEntry(container, '2026-07-15');

      final sub = container.listen(
        streakSummaryProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);

      await pumpEventQueue();

      expect(
        container.read(streakSummaryProvider),
        const StreakSummary(current: 1, longest: 1),
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

      await _seedEntry(container, '2026-07-10');
      await _seedEntry(container, '2026-07-11');
      await _seedEntry(container, '2026-07-12');

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

    test(
      'degrades to the empty summary when a stored date is malformed',
      () async {
        final db = newTestDatabase();
        addTearDown(db.close);
        final container = newTestContainer(
          db,
          overrides: [
            streakClockProvider.overrideWithValue(
              () => DateTime(2026, 7, 15, 9),
            ),
          ],
        );

        await _seedEntry(container, '2026/07/15');

        final sub = container.listen(
          streakSummaryProvider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(sub.close);

        await pumpEventQueue();

        expect(() => container.read(streakSummaryProvider), returnsNormally);
        expect(
          container.read(streakSummaryProvider),
          const StreakSummary.empty(),
        );
      },
    );

    testWidgets('the summary is read again at midnight and at 4 AM', (
      WidgetTester tester,
    ) async {
      DateTime now = DateTime(2026, 7, 13, 23, 30);
      final ProviderContainer container = ProviderContainer(
        overrides: [
          streakClockProvider.overrideWithValue(() => now),
          streakDaysProvider.overrideWith(
            (Ref ref) => Stream<List<StreakDay>>.value(<StreakDay>[
              _finished('2026-07-11'),
              _finished('2026-07-12'),
            ]),
          ),
        ],
      );
      final ProviderSubscription<StreakSummary> sub = container.listen(
        streakSummaryProvider,
        (_, _) {},
        fireImmediately: true,
      );
      await tester.pump();

      expect(
        container.read(streakSummaryProvider),
        const StreakSummary(current: 2, longest: 2),
      );

      now = DateTime(2026, 7, 14);
      await tester.pump(const Duration(minutes: 30));

      expect(
        container.read(streakSummaryProvider),
        StreakSummary(
          current: 2,
          longest: 2,
          lateNightDay: DateTime(2026, 7, 13),
        ),
      );

      now = DateTime(2026, 7, 14, 4);
      await tester.pump(const Duration(hours: 4));

      expect(
        container.read(streakSummaryProvider),
        const StreakSummary(current: 0, longest: 2),
      );

      sub.close();
      container.dispose();
    });
  });
}
