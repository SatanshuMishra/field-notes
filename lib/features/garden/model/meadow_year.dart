import 'dart:math' as math;

import 'package:field_notes/design/format/plural.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/core/capture_date.dart';
import 'package:field_notes/features/garden/model/garden_data.dart';
import 'package:field_notes/features/today/today_date.dart';

const List<String> _monthNames = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const int _secondBloomEntries = 3;
const int _spruceRun = 7;
const int _windowDays = 16;
const int _windowMoodDays = 6;
const int _weekCount = 52;
const int _daysPerWeek = 7;
const int _monthTopMoods = 2;
const int _heavyPercent = 45;
const int _changeablePercent = 25;
const String _rangeSeparator = ' – ';

double meadowValence(Mood mood) => switch (mood) {
  Mood.happy => 0.85,
  Mood.love => 0.8,
  Mood.warm => 0.7,
  Mood.grateful => 0.62,
  Mood.hopeful => 0.45,
  Mood.calm => 0.28,
  Mood.tired => -0.25,
  Mood.anxious => -0.45,
  Mood.angry => -0.65,
  Mood.sad => -0.75,
};

class MeadowDay {
  MeadowDay({
    required this.index,
    required this.date,
    required this.mood,
    required this.entries,
  }) : valence = mood == null ? 0 : meadowValence(mood);

  final int index;
  final String date;
  final Mood? mood;
  final int entries;
  final double valence;

  bool get isSprout => entries > 0 && mood == null;

  bool get secondBloom => entries >= _secondBloomEntries;

  bool get nods => valence < 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeadowDay &&
          runtimeType == other.runtimeType &&
          index == other.index &&
          date == other.date &&
          mood == other.mood &&
          entries == other.entries;

  @override
  int get hashCode => Object.hash(index, date, mood, entries);

  @override
  String toString() =>
      'MeadowDay(index: $index, date: $date, mood: $mood, entries: $entries)';
}

class MeadowRun {
  const MeadowRun({
    required this.first,
    required this.last,
    required this.length,
  });

  static const MeadowRun none = MeadowRun(first: 0, last: -1, length: 0);

  final int first;
  final int last;
  final int length;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeadowRun &&
          runtimeType == other.runtimeType &&
          first == other.first &&
          last == other.last &&
          length == other.length;

  @override
  int get hashCode => Object.hash(first, last, length);

  @override
  String toString() => 'MeadowRun(first: $first, last: $last, length: $length)';
}

class MeadowWindow {
  const MeadowWindow({
    required this.first,
    required this.last,
    required this.mean,
  });

  final int first;
  final int last;
  final double mean;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeadowWindow &&
          runtimeType == other.runtimeType &&
          first == other.first &&
          last == other.last &&
          mean == other.mean;

  @override
  int get hashCode => Object.hash(first, last, mean);

  @override
  String toString() => 'MeadowWindow(first: $first, last: $last, mean: $mean)';
}

class MeadowMonth {
  const MeadowMonth({
    required this.month,
    required this.first,
    required this.length,
    required this.planted,
    required this.topMoods,
  });

  final int month;
  final int first;
  final int length;
  final int planted;
  final List<Mood> topMoods;

  String get summary {
    final String name = _monthNames[month - 1];
    if (planted == 0) {
      return '$name, no days planted';
    }
    final String grown = '$name, ${pluralize(planted, 'day')} planted';
    if (topMoods.isEmpty) {
      return grown;
    }
    final String moods = topMoods.map((Mood mood) => mood.label).join(' and ');
    return '$grown, mostly $moods';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeadowMonth &&
          runtimeType == other.runtimeType &&
          month == other.month &&
          first == other.first &&
          length == other.length &&
          planted == other.planted &&
          _sameMoods(topMoods, other.topMoods);

  @override
  int get hashCode =>
      Object.hash(month, first, length, planted, Object.hashAll(topMoods));

  @override
  String toString() =>
      'MeadowMonth(month: $month, first: $first, length: $length, '
      'planted: $planted, topMoods: $topMoods)';
}

class MeadowYear {
  const MeadowYear._({
    required this.year,
    required this.daysInYear,
    required this.limit,
    required this.days,
    required this.blooms,
    required this.sprouts,
    required this.tally,
    required this.longestRun,
    required this.heaviest,
    required this.brightest,
    required this.heavyShare,
    required this.weeks,
    required this.months,
  });

  static MeadowYear build({
    required List<Day> days,
    required Map<String, int> entryCounts,
    required int year,
    required DateTime today,
  }) {
    final int daysInYear = _daysInYear(year);
    final int limit = _limitOf(year, daysInYear, today.toLocal());
    final List<MeadowDay> planted = <MeadowDay>[
      for (final GardenBloomData bloom in gardenBloomsForYear(days, year))
        if (_grownIndex(bloom.date, year, limit) case final int index)
          MeadowDay(
            index: index,
            date: bloom.date,
            mood: bloom.mood,
            entries: entryCounts[bloom.date] ?? 0,
          ),
      for (final String date in gardenSproutsForYear(
        days,
        entryCounts.keys.toList(),
        year,
      ))
        if (_grownIndex(date, year, limit) case final int index)
          MeadowDay(
            index: index,
            date: date,
            mood: null,
            entries: entryCounts[date] ?? 0,
          ),
    ];
    final Map<int, MeadowDay> byIndex = <int, MeadowDay>{
      for (final MeadowDay day in planted) day.index: day,
    };
    final List<MeadowDay?> grid = List<MeadowDay?>.unmodifiable(
      List<MeadowDay?>.generate(daysInYear, (int index) => byIndex[index]),
    );
    final List<MeadowDay> grown = grid.nonNulls.toList();
    final int blooms = grown.where((MeadowDay day) => day.mood != null).length;
    final int heavy = grown.where((MeadowDay day) => day.nods).length;
    final List<MeadowWindow> windows = _windows(grid);
    return MeadowYear._(
      year: year,
      daysInYear: daysInYear,
      limit: limit,
      days: grid,
      blooms: blooms,
      sprouts: grown.length - blooms,
      tally: List<MoodTallyEntry>.unmodifiable(
        moodTally(
          days
              .where((Day day) => _grownIndex(day.date, year, limit) != null)
              .toList(),
          year,
        ),
      ),
      longestRun: _longestRun(grid),
      heaviest: _extreme(windows, (double a, double b) => a < b),
      brightest: _extreme(windows, (double a, double b) => a > b),
      heavyShare: heavy / math.max(1, grown.length),
      weeks: List<Mood?>.unmodifiable(
        List<Mood?>.generate(_weekCount, (int week) {
          final int first = week * _daysPerWeek;
          return _topMoods(
            grid.sublist(first, first + _daysPerWeek),
            1,
          ).firstOrNull;
        }),
      ),
      months: List<MeadowMonth>.unmodifiable(
        List<MeadowMonth>.generate(
          DateTime.monthsPerYear,
          (int offset) => _monthOf(grid, year, offset + 1),
        ),
      ),
    );
  }

  final int year;
  final int daysInYear;
  final int limit;
  final List<MeadowDay?> days;
  final int blooms;
  final int sprouts;
  final List<MoodTallyEntry> tally;
  final MeadowRun longestRun;
  final MeadowWindow? heaviest;
  final MeadowWindow? brightest;
  final double heavyShare;
  final List<Mood?> weeks;
  final List<MeadowMonth> months;

  bool get hasSpruce => longestRun.length >= _spruceRun;

  String get weather {
    final int percent = (heavyShare * 100).round();
    if (percent > _heavyPercent) {
      return 'Heavy skies';
    }
    if (percent > _changeablePercent) {
      return 'Changeable skies';
    }
    return 'Clear skies';
  }
}

List<int> meadowYears({
  required List<Day> days,
  required Iterable<String> journaledDates,
  required int currentYear,
}) {
  final List<String> journaled = journaledDates.toList();
  final Set<int> candidates = <int>{
    for (final Day day in days) ?_yearOf(day.date),
    for (final String date in journaled) ?_yearOf(date),
  };
  final List<int> past =
      candidates
          .where(
            (int year) =>
                year < currentYear &&
                (gardenBloomsForYear(days, year).isNotEmpty ||
                    gardenSproutsForYear(days, journaled, year).isNotEmpty),
          )
          .toList()
        ..sort((int a, int b) => b.compareTo(a));
  return List<int>.unmodifiable(<int>[currentYear, ...past]);
}

String meadowCountPhrase(int blooms, int sprouts) =>
    '${pluralize(blooms, 'bloom')} and ${pluralize(sprouts, 'sprout')}';

String meadowRangeLabel(int year, int first, int last) =>
    '${_shortDay(year, first)}$_rangeSeparator${_shortDay(year, last)}';

String meadowRunLabel(int year, MeadowRun run) =>
    '${pluralize(run.length, 'day')} in a row · '
    '${meadowRangeLabel(year, run.first, run.last)}';

String _shortDay(int year, int index) =>
    shortMonthDayLabel(DateTime(year, 1, 1 + index));

int _daysInYear(int year) =>
    DateTime.utc(year + 1).difference(DateTime.utc(year)).inDays;

int _indexOf(DateTime date) => DateTime.utc(
  date.year,
  date.month,
  date.day,
).difference(DateTime.utc(date.year)).inDays;

int _limitOf(int year, int daysInYear, DateTime today) {
  if (year < today.year) {
    return daysInYear;
  }
  if (year > today.year) {
    return 0;
  }
  return _indexOf(today) + 1;
}

int? _yearOf(String date) =>
    date.length < 4 ? null : int.tryParse(date.substring(0, 4));

int? _grownIndex(String date, int year, int limit) {
  if (!isCaptureDateKey(date)) {
    return null;
  }
  final int month = int.parse(date.substring(5, 7));
  final int day = int.parse(date.substring(8, 10));
  final DateTime moment = DateTime.utc(
    int.parse(date.substring(0, 4)),
    month,
    day,
  );
  if (moment.year != year || moment.month != month || moment.day != day) {
    return null;
  }
  final int index = _indexOf(moment);
  return index < limit ? index : null;
}

MeadowRun _longestRun(List<MeadowDay?> grid) {
  MeadowRun best = MeadowRun.none;
  int start = 0;
  int length = 0;
  for (int index = 0; index < grid.length; index++) {
    if (grid[index] == null) {
      length = 0;
      continue;
    }
    if (length == 0) {
      start = index;
    }
    length++;
    if (length > best.length) {
      best = MeadowRun(first: start, last: index, length: length);
    }
  }
  return best;
}

List<MeadowWindow> _windows(List<MeadowDay?> grid) => <MeadowWindow>[
  for (int first = 0; first <= grid.length - _windowDays; first++)
    ?_windowAt(grid, first),
];

MeadowWindow? _windowAt(List<MeadowDay?> grid, int first) {
  final List<double> valences = <double>[
    for (final MeadowDay? day in grid.sublist(first, first + _windowDays))
      if (day != null && day.mood != null) day.valence,
  ];
  if (valences.length < _windowMoodDays) {
    return null;
  }
  final double sum = valences.fold(0, (double a, double b) => a + b);
  return MeadowWindow(
    first: first,
    last: first + _windowDays - 1,
    mean: sum / valences.length,
  );
}

MeadowWindow? _extreme(
  List<MeadowWindow> windows,
  bool Function(double candidate, double best) beats,
) {
  MeadowWindow? best;
  for (final MeadowWindow window in windows) {
    if (best == null || beats(window.mean, best.mean)) {
      best = window;
    }
  }
  return best;
}

List<Mood> _topMoods(List<MeadowDay?> days, int count) {
  final Map<Mood, int> counts = <Mood, int>{};
  for (final MeadowDay day in days.nonNulls) {
    final Mood? mood = day.mood;
    if (mood != null) {
      counts[mood] = (counts[mood] ?? 0) + 1;
    }
  }
  final List<Mood> ranked = <Mood>[
    for (final Mood mood in moodOrder)
      if (counts.containsKey(mood)) mood,
  ];
  ranked.sort((Mood a, Mood b) {
    final int byCount = (counts[b] ?? 0).compareTo(counts[a] ?? 0);
    if (byCount != 0) {
      return byCount;
    }
    return moodOrder.indexOf(a).compareTo(moodOrder.indexOf(b));
  });
  return List<Mood>.unmodifiable(ranked.take(count));
}

MeadowMonth _monthOf(List<MeadowDay?> grid, int year, int month) {
  final int first = _indexOf(DateTime.utc(year, month));
  final int length = DateTime.utc(year, month + 1, 0).day;
  final List<MeadowDay?> slice = grid.sublist(first, first + length);
  return MeadowMonth(
    month: month,
    first: first,
    length: length,
    planted: slice.nonNulls.length,
    topMoods: _topMoods(slice, _monthTopMoods),
  );
}

bool _sameMoods(List<Mood> a, List<Mood> b) {
  if (a.length != b.length) {
    return false;
  }
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
