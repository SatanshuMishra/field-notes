import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/capture/core/capture_date.dart';

import 'today_date.dart';

const int daysPerWeek = 7;

class TodayWeekCell {
  const TodayWeekCell({
    required this.date,
    required this.weekdayLabel,
    required this.isToday,
    this.mood,
  });

  final String date;
  final String weekdayLabel;
  final bool isToday;
  final Mood? mood;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TodayWeekCell &&
          runtimeType == other.runtimeType &&
          date == other.date &&
          weekdayLabel == other.weekdayLabel &&
          isToday == other.isToday &&
          mood == other.mood;

  @override
  int get hashCode => Object.hash(date, weekdayLabel, isToday, mood);

  @override
  String toString() =>
      'TodayWeekCell(date: $date, weekdayLabel: $weekdayLabel, '
      'isToday: $isToday, mood: $mood)';
}

List<String> weekDateKeys({
  required DateTime today,
  required WeekStart weekStart,
}) {
  final DateTime local = today.toLocal();
  final int isoWeekday = local.weekday;
  final int offsetFromStart =
      weekStart == WeekStart.monday ? isoWeekday - 1 : isoWeekday % daysPerWeek;
  return <String>[
    for (int index = 0; index < daysPerWeek; index++)
      captureDateKey(
        DateTime(local.year, local.month, local.day - offsetFromStart + index),
      ),
  ];
}

List<TodayWeekCell> buildWeekCells({
  required DateTime today,
  required WeekStart weekStart,
  required List<Day> days,
}) {
  final String todayKey = captureDateKey(today);
  final Map<String, Mood?> moodByDate = <String, Mood?>{
    for (final Day day in days)
      if (!day.isDeleted) day.date: day.mood,
  };
  return <TodayWeekCell>[
    for (final String key in weekDateKeys(today: today, weekStart: weekStart))
      TodayWeekCell(
        date: key,
        weekdayLabel: shortWeekdayLabel(parseDateKey(key) ?? today),
        isToday: key == todayKey,
        mood: moodByDate[key],
      ),
  ];
}
