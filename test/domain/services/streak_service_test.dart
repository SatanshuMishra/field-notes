import 'package:field_notes/domain/services/streak_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = StreakService();
  final today = DateTime(2026, 7, 15, 9, 30);

  group('StreakService.summarize', () {
    test('empty history yields the empty summary', () {
      expect(
        service.summarize(journaledDates: const <String>[], today: today),
        const StreakSummary.empty(),
      );
    });

    test('only today counts as a one-day current and longest streak', () {
      final result = service.summarize(
        journaledDates: const <String>['2026-07-15'],
        today: today,
      );
      expect(result, const StreakSummary(current: 1, longest: 1));
    });

    test('three consecutive days ending today', () {
      final result = service.summarize(
        journaledDates: const <String>['2026-07-13', '2026-07-14', '2026-07-15'],
        today: today,
      );
      expect(result, const StreakSummary(current: 3, longest: 3));
    });

    test('a gap breaks the current run at the most recent block', () {
      final result = service.summarize(
        journaledDates: const <String>[
          '2026-07-10',
          '2026-07-11',
          '2026-07-14',
          '2026-07-15',
        ],
        today: today,
      );
      expect(result, const StreakSummary(current: 2, longest: 2));
    });

    test('at local midnight, an unjournaled today keeps yesterday\'s run alive',
        () {
      final result = service.summarize(
        journaledDates: const <String>['2026-07-13', '2026-07-14', '2026-07-15'],
        today: DateTime(2026, 7, 16, 0, 0, 0),
      );
      expect(result, const StreakSummary(current: 3, longest: 3));
    });

    test('missing today and yesterday resets current but preserves longest', () {
      final result = service.summarize(
        journaledDates: const <String>['2026-07-10', '2026-07-11', '2026-07-12'],
        today: today,
      );
      expect(result, const StreakSummary(current: 0, longest: 3));
    });

    test('longest can exceed the current run', () {
      final result = service.summarize(
        journaledDates: const <String>[
          '2026-07-01',
          '2026-07-02',
          '2026-07-03',
          '2026-07-04',
          '2026-07-05',
          '2026-07-14',
          '2026-07-15',
        ],
        today: today,
      );
      expect(result, const StreakSummary(current: 2, longest: 5));
    });

    test('time of day never changes the result (local-midnight boundary)', () {
      final result = service.summarize(
        journaledDates: const <String>['2026-07-15'],
        today: DateTime(2026, 7, 15, 23, 59, 59),
      );
      expect(result.current, 1);
    });

    test('duplicate and unsorted dates are handled', () {
      final result = service.summarize(
        journaledDates: const <String>[
          '2026-07-15',
          '2026-07-13',
          '2026-07-15',
          '2026-07-14',
        ],
        today: today,
      );
      expect(result, const StreakSummary(current: 3, longest: 3));
    });

    test('a malformed date string throws FormatException', () {
      expect(
        () => service.summarize(
          journaledDates: const <String>['2026/07/15'],
          today: today,
        ),
        throwsFormatException,
      );
    });

    test('an impossible calendar date throws FormatException', () {
      expect(
        () => service.summarize(
          journaledDates: const <String>['2026-13-40'],
          today: today,
        ),
        throwsFormatException,
      );
    });
  });
}
