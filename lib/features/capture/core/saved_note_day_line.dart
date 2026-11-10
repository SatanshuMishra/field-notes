import 'package:field_notes/features/capture/core/capture_day_line.dart';
import 'package:field_notes/features/today/today_date.dart';

const String _weekdayBreak = ', ';
const String _clockJoin = ' · ';

CaptureDayLine savedNoteDayLine({
  required String dayTitle,
  required String clock,
}) {
  final int weekdayEnd = dayTitle.indexOf(_weekdayBreak);
  if (weekdayEnd < 0) {
    return (lead: dayTitle, date: clock);
  }
  return (
    lead: dayTitle.substring(0, weekdayEnd),
    date:
        '${dayTitle.substring(weekdayEnd + _weekdayBreak.length)}'
        '$_clockJoin$clock',
  );
}

CaptureDayLine savedNoteShortDayLine({
  required DateTime day,
  required String clock,
}) => (
  lead: shortWeekdayLabel(day),
  date: '${shortMonthDayLabel(day)}$_clockJoin$clock',
);
