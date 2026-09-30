import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/core/capture_date.dart';
import 'package:field_notes/features/garden/model/garden_data.dart';
import 'package:field_notes/features/garden/model/meadow_random.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/garden_harness.dart';

String _dateAt(int year, int index) =>
    captureDateKey(DateTime(year, 1, 1 + index));

List<Day> _moodDays(int year, Iterable<int> indices, Mood mood) => <Day>[
  for (final int index in indices) dayOf(_dateAt(year, index), mood: mood),
];

Iterable<int> _span(int first, int count) =>
    Iterable<int>.generate(count, (int i) => first + i);

MeadowYear _pastYear(
  int year,
  List<Day> days, {
  Map<String, int> entryCounts = const <String, int>{},
}) => MeadowYear.build(
  days: days,
  entryCounts: entryCounts,
  year: year,
  today: DateTime(year + 1, 3, 1),
);

void main() {
  test('one flower per day with a mood or an entry, up to today', () {
    final List<Day> days = <Day>[
      dayOf('2026-01-01', mood: Mood.happy),
      dayOf('2026-01-02'),
      dayOf('2026-01-03', mood: Mood.sad, deletedAt: 9),
      dayOf('2026-03-10', mood: Mood.calm),
      dayOf('2026-03-11', mood: Mood.warm),
      dayOf('2025-12-31', mood: Mood.love),
    ];
    const Map<String, int> entryCounts = <String, int>{
      '2026-01-01': 1,
      '2026-01-02': 2,
      '2026-01-03': 1,
      '2026-01-05': 1,
      '2026-03-12': 4,
    };

    final MeadowYear year = MeadowYear.build(
      days: days,
      entryCounts: entryCounts,
      year: 2026,
      today: DateTime(2026, 3, 10, 21, 30),
    );

    expect(year.year, 2026);
    expect(year.daysInYear, 365);
    expect(year.limit, 69);
    expect(year.days, hasLength(365));
    expect(
      year.days[0],
      MeadowDay(index: 0, date: '2026-01-01', mood: Mood.happy, entries: 1),
    );
    expect(year.days[0]!.valence, 0.85);
    expect(year.days[0]!.isSprout, isFalse);
    expect(
      year.days[1],
      MeadowDay(index: 1, date: '2026-01-02', mood: null, entries: 2),
    );
    expect(year.days[1]!.isSprout, isTrue);
    expect(year.days[1]!.valence, 0);
    expect(year.days[2], isNull);
    expect(year.days[4]!.isSprout, isTrue);
    expect(year.days[4]!.entries, 1);
    expect(
      year.days[68],
      MeadowDay(index: 68, date: '2026-03-10', mood: Mood.calm, entries: 0),
    );
    expect(year.days[68]!.isSprout, isFalse);
    expect(year.days[69], isNull);
    expect(year.days[70], isNull);
    expect(year.days.nonNulls.map((MeadowDay day) => day.index), <int>[
      0,
      1,
      4,
      68,
    ]);
    expect(year.blooms, 2);
    expect(year.sprouts, 2);
    expect(year.tally, const <MoodTallyEntry>[
      MoodTallyEntry(mood: Mood.happy, count: 1),
      MoodTallyEntry(mood: Mood.calm, count: 1),
    ]);
    expect(() => year.days[5] = null, throwsUnsupportedError);

    final MeadowYear past = MeadowYear.build(
      days: days,
      entryCounts: entryCounts,
      year: 2025,
      today: DateTime(2026, 3, 10),
    );
    expect(past.limit, 365);
    expect(past.days[364]!.mood, Mood.love);
    expect(past.blooms, 1);
    expect(past.sprouts, 0);

    final MeadowYear later = MeadowYear.build(
      days: <Day>[dayOf('2027-01-01', mood: Mood.warm)],
      entryCounts: const <String, int>{'2027-01-02': 1},
      year: 2027,
      today: DateTime(2026, 3, 10),
    );
    expect(later.limit, 0);
    expect(later.days.nonNulls, isEmpty);
    expect(later.blooms + later.sprouts, 0);
    expect(later.tally, isEmpty);
  });

  test('three or more entries make a second bloom and heavy moods nod', () {
    final List<Day> days = <Day>[
      for (int i = 0; i < moodOrder.length; i++)
        dayOf(_dateAt(2025, i), mood: moodOrder[i]),
    ];
    final Map<String, int> entryCounts = <String, int>{
      _dateAt(2025, 0): 3,
      _dateAt(2025, 1): 2,
      _dateAt(2025, 2): 5,
      _dateAt(2025, 20): 3,
      _dateAt(2025, 21): 1,
    };

    final MeadowYear year = _pastYear(2025, days, entryCounts: entryCounts);

    const Map<Mood, double> valences = <Mood, double>{
      Mood.happy: 0.85,
      Mood.love: 0.8,
      Mood.warm: 0.7,
      Mood.grateful: 0.62,
      Mood.hopeful: 0.45,
      Mood.calm: 0.28,
      Mood.tired: -0.25,
      Mood.anxious: -0.45,
      Mood.angry: -0.65,
      Mood.sad: -0.75,
    };
    const Set<Mood> heavy = <Mood>{
      Mood.tired,
      Mood.anxious,
      Mood.angry,
      Mood.sad,
    };
    for (int i = 0; i < moodOrder.length; i++) {
      final MeadowDay day = year.days[i]!;
      expect(day.mood, moodOrder[i]);
      expect(day.valence, valences[moodOrder[i]], reason: '${day.mood}');
      expect(meadowValence(moodOrder[i]), valences[moodOrder[i]]);
      expect(day.nods, heavy.contains(day.mood), reason: '${day.mood}');
    }
    expect(year.days[0]!.secondBloom, isTrue);
    expect(year.days[1]!.secondBloom, isFalse);
    expect(year.days[2]!.secondBloom, isTrue);
    expect(year.days[3]!.secondBloom, isFalse);
    expect(year.days[20]!.isSprout, isTrue);
    expect(year.days[20]!.secondBloom, isTrue);
    expect(year.days[20]!.nods, isFalse);
    expect(year.days[21]!.secondBloom, isFalse);
    expect(year.days[21]!.nods, isFalse);
  });

  test('a leap year has 366 days', () {
    final List<Day> days = <Day>[
      dayOf('2028-02-28', mood: Mood.calm),
      dayOf('2028-02-29', mood: Mood.warm),
      dayOf('2028-03-01', mood: Mood.hopeful),
      dayOf('2028-12-31', mood: Mood.love),
    ];

    final MeadowYear leap = _pastYear(2028, days);

    expect(leap.daysInYear, 366);
    expect(leap.limit, 366);
    expect(leap.days, hasLength(366));
    expect(leap.days[59]!.date, '2028-02-29');
    expect(leap.days[59]!.mood, Mood.warm);
    expect(leap.days[60]!.date, '2028-03-01');
    expect(leap.days[365]!.date, '2028-12-31');
    expect(leap.blooms, 4);
    expect(leap.months[1].length, 29);
    expect(leap.months[2].first, 60);
    expect(leap.months[11].first + leap.months[11].length, 366);

    final MeadowYear lastDay = MeadowYear.build(
      days: days,
      entryCounts: const <String, int>{},
      year: 2028,
      today: DateTime(2028, 12, 31, 23, 59),
    );
    expect(lastDay.limit, 366);
    expect(lastDay.days[365]!.mood, Mood.love);

    final MeadowYear common = _pastYear(2026, <Day>[
      dayOf('2026-02-29', mood: Mood.warm),
      dayOf('2026-02-28', mood: Mood.calm),
    ]);
    expect(common.daysInYear, 365);
    expect(common.days, hasLength(365));
    expect(common.months[1].length, 28);
    expect(common.blooms, 1);
    expect(common.days[58]!.date, '2026-02-28');
    expect(common.days[59], isNull);
  });

  test('landmarks need a seven-day run and six mood days in sixteen', () {
    final MeadowYear none = _pastYear(2025, const <Day>[]);
    expect(none.longestRun.length, 0);
    expect(none.hasSpruce, isFalse);
    expect(none.heaviest, isNull);
    expect(none.brightest, isNull);

    final MeadowYear six = _pastYear(
      2025,
      _moodDays(2025, _span(40, 6), Mood.calm),
    );
    expect(six.longestRun, const MeadowRun(first: 40, last: 45, length: 6));
    expect(six.hasSpruce, isFalse);

    final MeadowYear seven = _pastYear(
      2025,
      <Day>[
        ..._moodDays(2025, _span(10, 3), Mood.happy),
        dayOf(_dateAt(2025, 13)),
        ..._moodDays(2025, _span(14, 3), Mood.sad),
        ..._moodDays(2025, _span(100, 7), Mood.warm),
      ],
      entryCounts: <String, int>{_dateAt(2025, 13): 1},
    );
    expect(seven.longestRun, const MeadowRun(first: 10, last: 16, length: 7));
    expect(seven.hasSpruce, isTrue);
    expect(
      meadowRunLabel(2025, seven.longestRun),
      '7 days in a row · Jan 11 – Jan 17',
    );

    final MeadowYear fiveMoods = _pastYear(
      2025,
      <Day>[
        ..._moodDays(2025, <int>[0, 3, 6, 9, 12], Mood.sad),
        dayOf(_dateAt(2025, 1)),
        dayOf(_dateAt(2025, 2)),
        dayOf(_dateAt(2025, 4)),
      ],
      entryCounts: <String, int>{
        _dateAt(2025, 1): 1,
        _dateAt(2025, 2): 1,
        _dateAt(2025, 4): 2,
      },
    );
    expect(fiveMoods.heaviest, isNull);
    expect(fiveMoods.brightest, isNull);

    final MeadowYear sixMoods = _pastYear(
      2025,
      _moodDays(2025, <int>[0, 3, 6, 9, 12, 15], Mood.sad),
    );
    expect(
      sixMoods.heaviest,
      const MeadowWindow(first: 0, last: 15, mean: -0.75),
    );
    expect(sixMoods.brightest, sixMoods.heaviest);

    final MeadowYear spread = _pastYear(2025, <Day>[
      ..._moodDays(2025, _span(0, 6), Mood.happy),
      ..._moodDays(2025, _span(100, 6), Mood.sad),
      ..._moodDays(2025, _span(200, 6), Mood.calm),
      ..._moodDays(2025, <int>[300, 302, 304], Mood.angry),
      ..._moodDays(2025, <int>[301, 303, 305], Mood.love),
    ]);
    expect(spread.heaviest!.first, 90);
    expect(spread.heaviest!.last, 105);
    expect(spread.heaviest!.mean, closeTo(-0.75, 1e-12));
    expect(spread.brightest!.first, 0);
    expect(spread.brightest!.last, 15);
    expect(spread.brightest!.mean, closeTo(0.85, 1e-12));
    expect(
      meadowRangeLabel(2025, spread.heaviest!.first, spread.heaviest!.last),
      'Apr 1 – Apr 16',
    );

    final MeadowYear yearEnd = _pastYear(
      2028,
      _moodDays(2028, _span(360, 6), Mood.tired),
    );
    expect(
      yearEnd.heaviest,
      const MeadowWindow(first: 350, last: 365, mean: -0.25),
    );

    final MeadowYear beforeToday = MeadowYear.build(
      days: _moodDays(2026, _span(0, 6), Mood.sad),
      entryCounts: const <String, int>{},
      year: 2026,
      today: DateTime(2026, 1, 5),
    );
    expect(beforeToday.limit, 5);
    expect(beforeToday.heaviest, isNull);
    expect(beforeToday.brightest, isNull);
  });

  test('the weather phrase follows the share of heavy days', () {
    MeadowYear withHeavy(int heavyDays, int lightDays, {int sprouts = 0}) {
      final int total = heavyDays + lightDays;
      return _pastYear(
        2025,
        <Day>[
          ..._moodDays(2025, _span(0, heavyDays), Mood.sad),
          ..._moodDays(2025, _span(heavyDays, lightDays), Mood.warm),
        ],
        entryCounts: <String, int>{
          for (final int index in _span(total, sprouts))
            _dateAt(2025, index): 1,
        },
      );
    }

    final MeadowYear heavy = withHeavy(23, 27);
    expect(heavy.heavyShare, closeTo(0.46, 1e-12));
    expect(heavy.weather, 'Heavy skies');

    expect(withHeavy(9, 11).weather, 'Changeable skies');

    final MeadowYear changeable = withHeavy(13, 37);
    expect(changeable.heavyShare, closeTo(0.26, 1e-12));
    expect(changeable.weather, 'Changeable skies');

    expect(withHeavy(25, 75).weather, 'Clear skies');
    expect(withHeavy(1, 0, sprouts: 3).heavyShare, 0.25);
    expect(withHeavy(1, 0, sprouts: 3).weather, 'Clear skies');
    expect(withHeavy(1, 0, sprouts: 2).weather, 'Changeable skies');

    final MeadowYear empty = _pastYear(2025, const <Day>[]);
    expect(empty.heavyShare, 0);
    expect(empty.weather, 'Clear skies');
  });

  test('months, weeks and the list of years', () {
    final List<Day> days = <Day>[
      ..._moodDays(2025, _span(151, 9), Mood.tired),
      ..._moodDays(2025, _span(160, 7), Mood.hopeful),
      ..._moodDays(2025, _span(167, 5), Mood.calm),
      dayOf(_dateAt(2025, 172)),
      ..._moodDays(2025, <int>[181, 182], Mood.sad),
      ..._moodDays(2025, <int>[183, 184], Mood.happy),
      ..._moodDays(2025, <int>[212], Mood.love),
      ..._moodDays(2025, <int>[0, 1], Mood.calm),
      ..._moodDays(2025, <int>[2], Mood.sad),
      ..._moodDays(2025, <int>[7], Mood.angry),
      ..._moodDays(2025, <int>[8], Mood.happy),
    ];
    final Map<String, int> entryCounts = <String, int>{
      _dateAt(2025, 172): 1,
      _dateAt(2025, 243): 1,
      _dateAt(2025, 244): 2,
      _dateAt(2025, 245): 1,
      _dateAt(2025, 14): 1,
    };

    final MeadowYear year = _pastYear(2025, days, entryCounts: entryCounts);

    expect(year.months, hasLength(12));
    final MeadowMonth june = year.months[5];
    expect(june.month, 6);
    expect(june.first, 151);
    expect(june.length, 30);
    expect(june.planted, 22);
    expect(june.topMoods, <Mood>[Mood.tired, Mood.hopeful]);
    expect(june.summary, 'June, 22 days planted, mostly Tired and Hopeful');
    expect(
      year.months[6].summary,
      'July, 4 days planted, mostly Happy and Sad',
    );
    expect(year.months[7].topMoods, <Mood>[Mood.love]);
    expect(year.months[7].summary, 'August, 1 day planted, mostly Loved');
    expect(year.months[8].topMoods, isEmpty);
    expect(year.months[8].summary, 'September, 3 days planted');
    expect(
      year.months[0].summary,
      'January, 6 days planted, mostly Calm and Happy',
    );
    expect(year.months[9].planted, 0);
    expect(year.months[9].topMoods, isEmpty);
    expect(year.months[9].summary, 'October, no days planted');
    expect(
      year.months
          .map((MeadowMonth month) => month.length)
          .reduce((int a, int b) => a + b),
      365,
    );

    expect(year.weeks, hasLength(52));
    expect(year.weeks[0], Mood.calm);
    expect(year.weeks[1], Mood.happy);
    expect(year.weeks[2], isNull);
    expect(year.weeks[3], isNull);
    expect(year.weeks[21], Mood.tired);
    expect(year.weeks[23], Mood.hopeful);

    final List<Day> history = <Day>[
      dayOf('2026-02-01', mood: Mood.warm),
      dayOf('2024-05-05', mood: Mood.calm),
      dayOf('2024-06-06', mood: Mood.sad),
      dayOf('2023-01-01', mood: Mood.happy, deletedAt: 3),
      dayOf('2022-08-08'),
      dayOf('2027-01-01', mood: Mood.love),
      dayOf('bad', mood: Mood.love),
    ];
    expect(
      meadowYears(
        days: history,
        journaledDates: <String>['2021-05-05', '2024-05-06', '2027-02-02'],
        currentYear: 2026,
      ),
      <int>[2026, 2024, 2021],
    );
    expect(
      meadowYears(
        days: const <Day>[],
        journaledDates: const <String>[],
        currentYear: 2026,
      ),
      <int>[2026],
    );

    expect(meadowCountPhrase(1, 1), '1 bloom and 1 sprout');
    expect(meadowCountPhrase(129, 6), '129 blooms and 6 sprouts');
    expect(meadowCountPhrase(0, 2), '0 blooms and 2 sprouts');
    expect(meadowRangeLabel(2025, 12, 22), 'Jan 13 – Jan 23');
    expect(meadowRangeLabel(2028, 59, 365), 'Feb 29 – Dec 31');
    expect(
      meadowRunLabel(2025, const MeadowRun(first: 12, last: 22, length: 11)),
      '11 days in a row · Jan 13 – Jan 23',
    );

    final int partSeed = meadowPartSeed(
      meadowSeed(77, 2025),
      MeadowPart.plants,
    );
    final Set<int> itemSeeds = <int>{
      for (int index = 0; index < 366; index++) meadowItemSeed(partSeed, index),
    };
    expect(itemSeeds, hasLength(366));
    expect(meadowItemSeed(partSeed, 40), meadowItemSeed(partSeed, 40));
    expect(
      meadowItemSeed(partSeed, 40),
      isNot(
        meadowItemSeed(
          meadowPartSeed(meadowSeed(77, 2025), MeadowPart.drifts),
          40,
        ),
      ),
    );
  });
}
