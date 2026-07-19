class StreakSummary {
  const StreakSummary({required this.current, required this.longest});

  const StreakSummary.empty()
      : current = 0,
        longest = 0;

  final int current;
  final int longest;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StreakSummary &&
          runtimeType == other.runtimeType &&
          current == other.current &&
          longest == other.longest;

  @override
  int get hashCode => Object.hash(current, longest);

  @override
  String toString() => 'StreakSummary(current: $current, longest: $longest)';
}

class StreakService {
  const StreakService();

  static final RegExp _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  StreakSummary summarize({
    required Iterable<String> journaledDates,
    required DateTime today,
  }) {
    final ordinals = <int>{};
    for (final date in journaledDates) {
      ordinals.add(_ordinalFromString(date));
    }
    final todayOrdinal = _ordinal(today.year, today.month, today.day);
    return StreakSummary(
      current: _currentStreak(ordinals, todayOrdinal),
      longest: _longestStreak(ordinals),
    );
  }

  int _currentStreak(Set<int> ordinals, int todayOrdinal) {
    final int anchor;
    if (ordinals.contains(todayOrdinal)) {
      anchor = todayOrdinal;
    } else if (ordinals.contains(todayOrdinal - 1)) {
      anchor = todayOrdinal - 1;
    } else {
      return 0;
    }
    var count = 0;
    var cursor = anchor;
    while (ordinals.contains(cursor)) {
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

  int _ordinalFromString(String date) {
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
    return utc.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
  }

  int _ordinal(int year, int month, int day) =>
      DateTime.utc(year, month, day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;
}
