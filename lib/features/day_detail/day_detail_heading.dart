import 'package:field_notes/features/capture/core/capture_date.dart';
import 'package:field_notes/features/today/today_date.dart';

const String dayDetailKicker = 'a day in the garden';
const String dayDetailTodayKicker = 'today · in your garden';

class DayDetailHeading {
  const DayDetailHeading({required this.title});

  final String title;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DayDetailHeading &&
          runtimeType == other.runtimeType &&
          title == other.title;

  @override
  int get hashCode => title.hashCode;

  @override
  String toString() => 'DayDetailHeading(title: $title)';
}

DayDetailHeading dayDetailHeadingFor(String date, {DateTime? today}) {
  final DateTime? parsed = parseDateKey(date);
  if (parsed == null) {
    return DayDetailHeading(title: date);
  }
  return DayDetailHeading(
    title: dayTitleFor(parsed, today: today ?? DateTime.now()),
  );
}

String dayDetailKickerFor(String date, {required DateTime today}) {
  return date == captureDateKey(today) ? dayDetailTodayKicker : dayDetailKicker;
}
