import 'package:field_notes/features/today/today_date.dart';

typedef CaptureDayLine = ({String lead, String date});

CaptureDayLine captureDayLine({
  required DateTime day,
  required DateTime today,
}) {
  final DateTime local = day.toLocal();
  final DateTime localToday = today.toLocal();
  final bool isToday =
      local.year == localToday.year &&
      local.month == localToday.month &&
      local.day == localToday.day;
  return (
    lead: isToday ? 'today' : 'adding to',
    date: dayTitleFor(day, today: today),
  );
}
