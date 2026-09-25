import 'package:field_notes/domain/models/models.dart';

class GardenBloomData {
  const GardenBloomData({required this.date, required this.mood});

  final String date;
  final Mood mood;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GardenBloomData &&
          runtimeType == other.runtimeType &&
          date == other.date &&
          mood == other.mood;

  @override
  int get hashCode => Object.hash(date, mood);

  @override
  String toString() => 'GardenBloomData(date: $date, mood: $mood)';
}

class MoodTallyEntry {
  const MoodTallyEntry({required this.mood, required this.count});

  final Mood mood;
  final int count;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MoodTallyEntry &&
          runtimeType == other.runtimeType &&
          mood == other.mood &&
          count == other.count;

  @override
  int get hashCode => Object.hash(mood, count);

  @override
  String toString() => 'MoodTallyEntry(mood: $mood, count: $count)';
}

bool _isInYear(String date, int year) {
  if (date.length < 4) {
    return false;
  }
  return int.tryParse(date.substring(0, 4)) == year;
}

bool _isPlantable(Day day, int year) =>
    !day.isDeleted && day.mood != null && _isInYear(day.date, year);

List<GardenBloomData> gardenBloomsForYear(List<Day> days, int year) {
  final List<GardenBloomData> blooms = <GardenBloomData>[];
  for (final Day day in days) {
    final Mood? mood = day.mood;
    if (mood == null || !_isPlantable(day, year)) {
      continue;
    }
    blooms.add(GardenBloomData(date: day.date, mood: mood));
  }
  blooms.sort(
    (GardenBloomData a, GardenBloomData b) => a.date.compareTo(b.date),
  );
  return blooms;
}

List<MoodTallyEntry> moodTally(List<Day> days, int year) {
  final Map<Mood, int> counts = <Mood, int>{};
  for (final Day day in days) {
    final Mood? mood = day.mood;
    if (mood == null || !_isPlantable(day, year)) {
      continue;
    }
    counts[mood] = (counts[mood] ?? 0) + 1;
  }
  final List<MoodTallyEntry> tally = <MoodTallyEntry>[];
  for (final Mood mood in moodOrder) {
    final int count = counts[mood] ?? 0;
    if (count > 0) {
      tally.add(MoodTallyEntry(mood: mood, count: count));
    }
  }
  return tally;
}

List<String> gardenSproutsForYear(
  List<Day> days,
  List<String> journaledDates,
  int year,
) {
  final Set<String> knownDates = <String>{for (final Day day in days) day.date};
  final Map<String, Day> liveDays = <String, Day>{
    for (final Day day in days)
      if (!day.isDeleted) day.date: day,
  };
  final Set<String> sprouts = <String>{
    for (final String date in journaledDates)
      if (_isInYear(date, year) && _isSproutDate(date, knownDates, liveDays))
        date,
  };
  return sprouts.toList()..sort();
}

bool _isSproutDate(
  String date,
  Set<String> knownDates,
  Map<String, Day> liveDays,
) {
  final Day? live = liveDays[date];
  if (live == null) {
    return !knownDates.contains(date);
  }
  return live.mood == null;
}
