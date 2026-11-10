import 'package:field_notes/domain/services/streak_service.dart';
import 'package:flutter_test/flutter_test.dart';

int _at(int year, int month, int day, [int hour = 0, int minute = 0]) =>
    DateTime(year, month, day, hour, minute).millisecondsSinceEpoch;

StreakDay _finished(String date, {int? bloomPickedAt, int? firstLogAt}) {
  return StreakDay(
    date: date,
    hasBloom: true,
    logCount: 1,
    bloomPickedAt: bloomPickedAt,
    firstLogAt: firstLogAt,
  );
}

List<StreakDay> _finishedDays(List<String> dates) => <StreakDay>[
  for (final String date in dates) _finished(date),
];

void main() {
  const service = StreakService();
  final today = DateTime(2026, 7, 15, 9, 30);

  group('isDayComplete', () {
    test('needs both a bloom and at least one log', () {
      expect(isDayComplete(hasBloom: true, logCount: 1), isTrue);
      expect(isDayComplete(hasBloom: true, logCount: 3), isTrue);
      expect(isDayComplete(hasBloom: true, logCount: 0), isFalse);
      expect(isDayComplete(hasBloom: false, logCount: 2), isFalse);
      expect(isDayComplete(hasBloom: false, logCount: 0), isFalse);
    });
  });

  group('nextStreakBoundary', () {
    test('is 4 AM before it and the next midnight after it', () {
      expect(
        nextStreakBoundary(DateTime(2026, 7, 15, 1)),
        DateTime(2026, 7, 15, 4),
      );
      expect(
        nextStreakBoundary(DateTime(2026, 7, 15, 4)),
        DateTime(2026, 7, 16),
      );
      expect(
        nextStreakBoundary(DateTime(2026, 7, 15, 23, 59)),
        DateTime(2026, 7, 16),
      );
    });
  });

  group('StreakService.summarize', () {
    test('empty history yields the empty summary', () {
      expect(
        service.summarize(days: const <StreakDay>[], now: today),
        const StreakSummary.empty(),
      );
    });

    test('only today counts as a one-day current and longest streak', () {
      final result = service.summarize(
        days: _finishedDays(const <String>['2026-07-15']),
        now: today,
      );
      expect(result, const StreakSummary(current: 1, longest: 1));
    });

    test('three consecutive days ending today', () {
      final result = service.summarize(
        days: _finishedDays(const <String>[
          '2026-07-13',
          '2026-07-14',
          '2026-07-15',
        ]),
        now: today,
      );
      expect(result, const StreakSummary(current: 3, longest: 3));
    });

    test('a day with a log and no bloom breaks the run', () {
      final result = service.summarize(
        days: <StreakDay>[
          _finished('2026-07-12'),
          const StreakDay(date: '2026-07-13', hasBloom: false, logCount: 2),
          _finished('2026-07-14'),
          _finished('2026-07-15'),
        ],
        now: today,
      );
      expect(result, const StreakSummary(current: 2, longest: 2));
    });

    test('a day with a bloom and no log breaks the run', () {
      final result = service.summarize(
        days: <StreakDay>[
          _finished('2026-07-13'),
          const StreakDay(date: '2026-07-14', hasBloom: true, logCount: 0),
          _finished('2026-07-15'),
        ],
        now: today,
      );
      expect(result, const StreakSummary(current: 1, longest: 1));
    });

    test('a day with both its bloom and a log counts', () {
      final result = service.summarize(
        days: <StreakDay>[
          _finished(
            '2026-07-14',
            bloomPickedAt: _at(2026, 7, 14, 20),
            firstLogAt: _at(2026, 7, 14, 9),
          ),
          _finished(
            '2026-07-15',
            bloomPickedAt: _at(2026, 7, 15, 8),
            firstLogAt: _at(2026, 7, 15, 8, 5),
          ),
        ],
        now: today,
      );
      expect(result, const StreakSummary(current: 2, longest: 2));
    });

    test('a day from before bloom times counts with both parts', () {
      final result = service.summarize(
        days: <StreakDay>[
          _finished('2026-07-14', firstLogAt: _at(2026, 7, 20)),
          _finished(
            '2026-07-15',
            bloomPickedAt: _at(2026, 7, 15, 8),
            firstLogAt: _at(2026, 7, 15, 8),
          ),
        ],
        now: today,
      );
      expect(result, const StreakSummary(current: 2, longest: 2));
    });

    test('yesterday finished at 3:30 AM today counts', () {
      final result = service.summarize(
        days: <StreakDay>[
          _finished('2026-07-13'),
          _finished(
            '2026-07-14',
            bloomPickedAt: _at(2026, 7, 15, 3, 30),
            firstLogAt: _at(2026, 7, 15, 3, 20),
          ),
        ],
        now: today,
      );
      expect(result, const StreakSummary(current: 2, longest: 2));
    });

    test('yesterday finished at 4:30 AM today does not count', () {
      final result = service.summarize(
        days: <StreakDay>[
          _finished('2026-07-13'),
          _finished(
            '2026-07-14',
            bloomPickedAt: _at(2026, 7, 15, 4, 30),
            firstLogAt: _at(2026, 7, 14, 21),
          ),
        ],
        now: today,
      );
      expect(result, const StreakSummary(current: 0, longest: 1));
    });

    test('a first log after 4 AM the next morning does not count', () {
      final result = service.summarize(
        days: <StreakDay>[
          _finished(
            '2026-07-14',
            bloomPickedAt: _at(2026, 7, 14, 21),
            firstLogAt: _at(2026, 7, 15, 4, 30),
          ),
        ],
        now: today,
      );
      expect(result, const StreakSummary.empty());
    });

    test('before 4 AM an unfinished yesterday keeps the run and waits', () {
      final result = service.summarize(
        days: _finishedDays(const <String>['2026-07-12', '2026-07-13']),
        now: DateTime(2026, 7, 15, 1),
      );
      expect(
        result,
        StreakSummary(
          current: 2,
          longest: 2,
          lateNightDay: DateTime(2026, 7, 14),
        ),
      );
    });

    test('at 4 AM an unfinished yesterday breaks the run', () {
      final result = service.summarize(
        days: _finishedDays(const <String>['2026-07-12', '2026-07-13']),
        now: DateTime(2026, 7, 15, 4),
      );
      expect(result, const StreakSummary(current: 0, longest: 2));
    });

    test('before 4 AM a finished yesterday needs no grace', () {
      final result = service.summarize(
        days: _finishedDays(const <String>['2026-07-13', '2026-07-14']),
        now: DateTime(2026, 7, 15, 1),
      );
      expect(result, const StreakSummary(current: 2, longest: 2));
    });

    test('before 4 AM with no run to keep there is nothing to wait for', () {
      final result = service.summarize(
        days: _finishedDays(const <String>['2026-07-10']),
        now: DateTime(2026, 7, 15, 1),
      );
      expect(result, const StreakSummary(current: 0, longest: 1));
    });

    test('a gap breaks the current run at the most recent block', () {
      final result = service.summarize(
        days: _finishedDays(const <String>[
          '2026-07-10',
          '2026-07-11',
          '2026-07-14',
          '2026-07-15',
        ]),
        now: today,
      );
      expect(result, const StreakSummary(current: 2, longest: 2));
    });

    test('an unfinished today keeps yesterday\'s run alive', () {
      final result = service.summarize(
        days: _finishedDays(const <String>[
          '2026-07-13',
          '2026-07-14',
          '2026-07-15',
        ]),
        now: DateTime(2026, 7, 16, 9),
      );
      expect(result, const StreakSummary(current: 3, longest: 3));
    });

    test(
      'missing today and yesterday resets current but preserves longest',
      () {
        final result = service.summarize(
          days: _finishedDays(const <String>[
            '2026-07-10',
            '2026-07-11',
            '2026-07-12',
          ]),
          now: today,
        );
        expect(result, const StreakSummary(current: 0, longest: 3));
      },
    );

    test('longest can exceed the current run', () {
      final result = service.summarize(
        days: _finishedDays(const <String>[
          '2026-07-01',
          '2026-07-02',
          '2026-07-03',
          '2026-07-04',
          '2026-07-05',
          '2026-07-14',
          '2026-07-15',
        ]),
        now: today,
      );
      expect(result, const StreakSummary(current: 2, longest: 5));
    });

    test('duplicate and unsorted dates are handled', () {
      final result = service.summarize(
        days: _finishedDays(const <String>[
          '2026-07-15',
          '2026-07-13',
          '2026-07-15',
          '2026-07-14',
        ]),
        now: today,
      );
      expect(result, const StreakSummary(current: 3, longest: 3));
    });

    test('a malformed date string throws FormatException', () {
      expect(
        () => service.summarize(
          days: _finishedDays(const <String>['2026/07/15']),
          now: today,
        ),
        throwsFormatException,
      );
    });

    test('an impossible calendar date throws FormatException', () {
      expect(
        () => service.summarize(
          days: _finishedDays(const <String>['2026-13-40']),
          now: today,
        ),
        throwsFormatException,
      );
    });
  });
}
