import 'package:field_notes/features/capture/core/capture_date.dart';

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

const List<String> _weekdayNames = <String>[
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const int _afternoonHour = 12;
const int _eveningHour = 17;

String greetingFor(DateTime moment) {
  final int hour = moment.toLocal().hour;
  if (hour < _afternoonHour) {
    return 'Good morning';
  }
  if (hour < _eveningHour) {
    return 'Good afternoon';
  }
  return 'Good evening';
}

String longDateLabel(DateTime moment) {
  final DateTime local = moment.toLocal();
  final String weekday = _weekdayNames[local.weekday - 1];
  final String month = _monthNames[local.month - 1];
  return '$weekday, $month ${local.day}, ${local.year}';
}

String shortWeekdayLabel(DateTime moment) {
  return _weekdayNames[moment.toLocal().weekday - 1].substring(0, 3);
}

String yearsAgoLabel(int years) {
  return years == 1 ? '1 year ago' : '$years years ago';
}

DateTime? parseDateKey(String value) {
  if (!isCaptureDateKey(value)) {
    return null;
  }
  final DateTime parsed = DateTime(
    int.parse(value.substring(0, 4)),
    int.parse(value.substring(5, 7)),
    int.parse(value.substring(8, 10)),
  );
  return captureDateKey(parsed) == value ? parsed : null;
}
