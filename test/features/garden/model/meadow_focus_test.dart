import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/core/capture_date.dart';
import 'package:field_notes/features/garden/model/meadow_focus.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/scene/meadow_view.dart';
import 'package:field_notes/features/garden/widgets/meadow_landmarks.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/garden_harness.dart';

List<Day> _days(int year, Iterable<int> days, Mood mood) => <Day>[
  for (final int day in days)
    dayOf(captureDateKey(DateTime(year, 1, day)), mood: mood),
];

Iterable<int> _through(int first, int last) =>
    Iterable<int>.generate(last - first + 1, (int i) => first + i);

MeadowYear _year() => MeadowYear.build(
  days: <Day>[
    ..._days(2025, _through(1, 10), Mood.happy),
    ..._days(2025, _through(11, 20), Mood.sad),
  ],
  entryCounts: <String, int>{captureDateKey(DateTime(2025, 1, 25)): 1},
  year: 2025,
  today: DateTime(2026, 3, 1, 9),
);

void main() {
  test('focus steps through months and landmarks and stops at the ends', () {
    final MeadowYear year = _year();

    final MeadowFocus january = MeadowFocus.month(year, 0);
    expect(january.kind, MeadowFocusKind.month);
    expect(january.title, 'January');
    expect(january.range, const MeadowRange(first: 0, last: 30, key: 'm0'));
    expect(january.isFirst, isTrue);
    expect(january.isLast, isFalse);
    expect(january.noun, 'month');

    final MeadowFocus february = january.step(year, 1, isCurrentYear: false);
    expect(february.title, 'February');
    expect(february.index, 1);
    expect(february.range, const MeadowRange(first: 31, last: 58, key: 'm1'));
    expect(january.step(year, -1, isCurrentYear: false), january);
    expect(february.step(year, -1, isCurrentYear: false), january);

    final MeadowFocus december = MeadowFocus.month(year, 11);
    expect(december.title, 'December');
    expect(december.isLast, isTrue);
    expect(december.range.last, year.daysInYear - 1);
    expect(december.step(year, 1, isCurrentYear: false), december);

    expect(
      january.countsIn(year, growthPoint: year.limit).label,
      '20 blooms · 1 sprout',
    );
    expect(january.countsIn(year, growthPoint: 5).label, '5 blooms');
    expect(february.countsIn(year, growthPoint: year.limit).label, '0 blooms');
    expect(
      const MeadowFocusCounts(blooms: 1, sprouts: 2).label,
      '1 bloom · 2 sprouts',
    );

    final List<MeadowLandmark> all = meadowLandmarks(
      year,
      isCurrentYear: false,
    );
    final List<MeadowLandmark> ranged = meadowRangedLandmarks(
      year,
      isCurrentYear: false,
    );
    expect(all.where((MeadowLandmark l) => l.range == null), isNotEmpty);
    expect(ranged.map((MeadowLandmark l) => l.title), <String>[
      'The old spruce',
      'Mist in the hollow',
      'Butterflies',
    ]);

    final MeadowFocus spruce = MeadowFocus.landmark(
      year,
      0,
      isCurrentYear: false,
    )!;
    expect(spruce.kind, MeadowFocusKind.landmark);
    expect(spruce.noun, 'landmark');
    expect(spruce.title, 'The old spruce');
    expect(spruce.range, ranged[0].range);
    expect(spruce.count, 3);
    expect(spruce.isFirst, isTrue);
    expect(spruce.step(year, -1, isCurrentYear: false), spruce);

    final MeadowFocus mist = spruce.step(year, 1, isCurrentYear: false);
    expect(mist.title, 'Mist in the hollow');
    expect(mist.range, ranged[1].range);
    final MeadowFocus butterflies = mist.step(year, 1, isCurrentYear: false);
    expect(butterflies.title, 'Butterflies');
    expect(butterflies.isLast, isTrue);
    expect(butterflies.step(year, 1, isCurrentYear: false), butterflies);
    expect(<String>[
      spruce.title,
      mist.title,
      butterflies.title,
    ], isNot(contains(year.weather)));

    final MeadowYear bare = MeadowYear.build(
      days: const <Day>[],
      entryCounts: const <String, int>{},
      year: 2025,
      today: DateTime(2026, 3, 1, 9),
    );
    expect(MeadowFocus.landmark(bare, 0, isCurrentYear: false), isNull);
  });
}
