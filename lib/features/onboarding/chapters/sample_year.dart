import 'dart:math' as math;

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/core/capture_date.dart';
import 'package:field_notes/features/garden/model/meadow_random.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';

const int sampleYearNumber = 2023;
const int sampleYearDays = 365;

const int _sampleKey = 6650;
const int _seedScale = 31;
const int _seedOffset = 7;
const double _keptShare = 0.68;
const List<double> _arc = <double>[
  0.05,
  0.1,
  0,
  0.2,
  0.45,
  0.75,
  0.85,
  0.85,
  0.75,
  0.75,
  0.65,
  0.75,
  0.8,
];
const Map<Mood, double> _bias = <Mood, double>{
  Mood.love: 0.28,
  Mood.warm: 0.06,
};
const int _arcSteps = 12;
const double _arcEnd = 11.999;
const int _gapCountSpan = 3;
const int _gapStartLeast = 10;
const int _gapStartSpan = 330;
const int _gapLengthLeast = 4;
const int _gapLengthSpan = 10;
const double _carry = 0.5;
const double _wander = 1;
const double _wordlessChance = 0.045;
const double _repeatChance = 0.32;
const double _repeatReach = 0.4;
const double _moodJitter = 0.38;
const double _farthest = 9;
const double _oneEntryChance = 0.66;
const double _twoEntriesChance = 0.9;
const int _manyEntriesLeast = 3;
const int _manyEntriesSpan = 2;

final int sampleMeadowSeed = meadowSeed(_sampleKey, sampleYearNumber);

typedef _Gap = ({int first, int last});

double _arcAt(double fraction) {
  final double x = math.min(_arcEnd, fraction * _arcSteps);
  final int step = x.floor();
  final double within = x - step;
  final double eased = within * within * (3 - 2 * within);
  return _arc[step] + (_arc[step + 1] - _arc[step]) * eased;
}

_Gap _gap(MeadowRandom random) {
  final int first = _gapStartLeast + random.nextInt(_gapStartSpan);
  return (
    first: first,
    last: first + _gapLengthLeast + random.nextInt(_gapLengthSpan),
  );
}

Mood _nearest(MeadowRandom random, double pull) {
  Mood nearest = moodOrder.first;
  double best = _farthest;
  for (final Mood mood in moodOrder) {
    final double score =
        (meadowValence(mood) - pull).abs() +
        random.next() * _moodJitter -
        (_bias[mood] ?? 0);
    if (score < best) {
      best = score;
      nearest = mood;
    }
  }
  return nearest;
}

int _entriesOf(MeadowRandom random) {
  final double draw = random.next();
  if (draw < _oneEntryChance) {
    return 1;
  }
  if (draw < _twoEntriesChance) {
    return 2;
  }
  return _manyEntriesLeast + random.nextInt(_manyEntriesSpan);
}

Day _sampleDay(String date, Mood? mood) =>
    Day(id: 'sample-$date', date: date, mood: mood, createdAt: 0, updatedAt: 0);

MeadowYear buildSampleMeadowYear() {
  final MeadowRandom random = MeadowRandom(
    _sampleKey * _seedScale + _seedOffset,
  );
  final int gapCount = 1 + random.nextInt(_gapCountSpan);
  final List<_Gap> gaps = List<_Gap>.unmodifiable(<_Gap>[
    for (int gap = 0; gap < gapCount; gap++) _gap(random),
  ]);
  final List<Day> days = <Day>[];
  final Map<String, int> entryCounts = <String, int>{};
  double pull = _arcAt(0);
  Mood? previous;
  for (int index = 0; index < sampleYearDays; index++) {
    final String date = captureDateKey(
      DateTime(sampleYearNumber, 1, 1 + index),
    );
    final bool skipped =
        gaps.any((_Gap gap) => index >= gap.first && index <= gap.last) ||
        random.next() > _keptShare;
    if (skipped) {
      days.add(_sampleDay(date, null));
      continue;
    }
    pull =
        pull * _carry +
        (_arcAt(index / sampleYearDays) + (random.next() - 0.5) * _wander) *
            _carry;
    Mood? mood;
    if (random.next() > _wordlessChance) {
      final Mood? last = previous;
      mood =
          last != null &&
              random.next() < _repeatChance &&
              (meadowValence(last) - pull).abs() < _repeatReach
          ? last
          : _nearest(random, pull);
      previous = mood;
    }
    entryCounts[date] = _entriesOf(random);
    days.add(_sampleDay(date, mood));
  }
  return MeadowYear.build(
    days: List<Day>.unmodifiable(days),
    entryCounts: Map<String, int>.unmodifiable(entryCounts),
    year: sampleYearNumber,
    today: DateTime(sampleYearNumber + 1),
  );
}
