const int lateNightEndHour = 4;

bool isDayComplete({required bool hasBloom, required int logCount}) =>
    hasBloom && logCount > 0;

DateTime nextStreakBoundary(DateTime now) {
  final DateTime lateNightEnds = DateTime(
    now.year,
    now.month,
    now.day,
    lateNightEndHour,
  );
  return now.isBefore(lateNightEnds)
      ? lateNightEnds
      : DateTime(now.year, now.month, now.day + 1);
}

class StreakDay {
  const StreakDay({
    required this.date,
    required this.hasBloom,
    required this.logCount,
    this.bloomPickedAt,
    this.firstLogAt,
  });

  final String date;
  final bool hasBloom;
  final int logCount;
  final int? bloomPickedAt;
  final int? firstLogAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StreakDay &&
          date == other.date &&
          hasBloom == other.hasBloom &&
          logCount == other.logCount &&
          bloomPickedAt == other.bloomPickedAt &&
          firstLogAt == other.firstLogAt;

  @override
  int get hashCode =>
      Object.hash(date, hasBloom, logCount, bloomPickedAt, firstLogAt);

  @override
  String toString() =>
      'StreakDay(date: $date, hasBloom: $hasBloom, logCount: $logCount, '
      'bloomPickedAt: $bloomPickedAt, firstLogAt: $firstLogAt)';
}

class StreakSummary {
  const StreakSummary({
    required this.current,
    required this.longest,
    this.lateNightDay,
  });

  const StreakSummary.empty() : current = 0, longest = 0, lateNightDay = null;

  final int current;
  final int longest;
  final DateTime? lateNightDay;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StreakSummary &&
          runtimeType == other.runtimeType &&
          current == other.current &&
          longest == other.longest &&
          lateNightDay == other.lateNightDay;

  @override
  int get hashCode => Object.hash(current, longest, lateNightDay);

  @override
  String toString() =>
      'StreakSummary(current: $current, longest: $longest, '
      'lateNightDay: $lateNightDay)';
}

class StreakService {
  const StreakService();

  static final RegExp _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  StreakSummary summarize({
    required Iterable<StreakDay> days,
    required DateTime now,
  }) {
    final Set<int> counted = <int>{
      for (final StreakDay day in days)
        if (_parse(day.date) case final DateTime date when _counts(day, date))
          _ordinalOf(date),
    };
    final DateTime today = DateTime(now.year, now.month, now.day);
    final int todayOrdinal = _ordinalOf(today);
    final int yesterday = todayOrdinal - 1;
    final bool yesterdayOpen =
        now.isBefore(
          DateTime(now.year, now.month, now.day, lateNightEndHour),
        ) &&
        !counted.contains(yesterday);
    final bool runWaits = yesterdayOpen && counted.contains(yesterday - 1);
    return StreakSummary(
      current: _currentStreak(counted, todayOrdinal, yesterdayOpen),
      longest: _longestStreak(counted),
      lateNightDay: runWaits
          ? DateTime(now.year, now.month, now.day - 1)
          : null,
    );
  }

  bool _counts(StreakDay day, DateTime date) {
    if (!isDayComplete(hasBloom: day.hasBloom, logCount: day.logCount)) {
      return false;
    }
    final int? picked = day.bloomPickedAt;
    if (picked == null) {
      return true;
    }
    final int closes = DateTime(
      date.year,
      date.month,
      date.day + 1,
      lateNightEndHour,
    ).millisecondsSinceEpoch;
    final int? firstLog = day.firstLogAt;
    return picked < closes && firstLog != null && firstLog < closes;
  }

  int _currentStreak(Set<int> counted, int todayOrdinal, bool yesterdayOpen) {
    var count = counted.contains(todayOrdinal) ? 1 : 0;
    var cursor = yesterdayOpen ? todayOrdinal - 2 : todayOrdinal - 1;
    while (counted.contains(cursor)) {
      count++;
      cursor--;
    }
    return count;
  }

  int _longestStreak(Set<int> ordinals) {
    if (ordinals.isEmpty) {
      return 0;
    }
    final sorted = ordinals.toList()..sort();
    var longest = 0;
    var run = 0;
    int? previous;
    for (final ordinal in sorted) {
      run = previous != null && ordinal == previous + 1 ? run + 1 : 1;
      if (run > longest) {
        longest = run;
      }
      previous = ordinal;
    }
    return longest;
  }

  DateTime _parse(String date) {
    if (!_datePattern.hasMatch(date)) {
      throw FormatException('Expected a YYYY-MM-DD journaled date', date);
    }
    final year = int.parse(date.substring(0, 4));
    final month = int.parse(date.substring(5, 7));
    final day = int.parse(date.substring(8, 10));
    final utc = DateTime.utc(year, month, day);
    if (utc.year != year || utc.month != month || utc.day != day) {
      throw FormatException('Not a valid calendar date', date);
    }
    return DateTime(year, month, day);
  }

  int _ordinalOf(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;
}
