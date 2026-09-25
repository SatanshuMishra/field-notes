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

const List<String> _weekdayLetters = <String>[
  'M',
  'T',
  'W',
  'T',
  'F',
  'S',
  'S',
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

class MonthRef {
  const MonthRef(this.year, this.month);

  factory MonthRef.forDate(DateTime date) => MonthRef(date.year, date.month);

  final int year;
  final int month;

  MonthRef get previous =>
      month == 1 ? MonthRef(year - 1, 12) : MonthRef(year, month - 1);

  MonthRef get next =>
      month == 12 ? MonthRef(year + 1, 1) : MonthRef(year, month + 1);

  String get title => '${_monthNames[month - 1]} $year';

  String dateKey(int day) => '${_pad4(year)}-${_pad2(month)}-${_pad2(day)}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MonthRef &&
          runtimeType == other.runtimeType &&
          year == other.year &&
          month == other.month;

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() => 'MonthRef($year, $month)';
}

class CalendarCell {
  const CalendarCell.day({
    required this.dayOfMonth,
    required this.dateKey,
    this.isInMonth = true,
  });

  final int dayOfMonth;
  final String dateKey;
  final bool isInMonth;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalendarCell &&
          runtimeType == other.runtimeType &&
          dayOfMonth == other.dayOfMonth &&
          dateKey == other.dateKey &&
          isInMonth == other.isInMonth;

  @override
  int get hashCode => Object.hash(dayOfMonth, dateKey, isInMonth);
}

List<CalendarCell> monthGridCells(
  MonthRef month, {
  int firstWeekday = DateTime.sunday,
}) {
  final int firstWeekdayOfMonth = DateTime(month.year, month.month, 1).weekday;
  final int daysInMonth = DateTime(month.year, month.month + 1, 0).day;
  final int leading = (firstWeekdayOfMonth - firstWeekday + 7) % 7;
  final int weekCount = (leading + daysInMonth + 6) ~/ 7;

  return List<CalendarCell>.unmodifiable(<CalendarCell>[
    for (int index = 0; index < weekCount * 7; index++)
      _cellFor(DateTime(month.year, month.month, 1 - leading + index), month),
  ]);
}

CalendarCell _cellFor(DateTime date, MonthRef month) {
  final MonthRef dateMonth = MonthRef.forDate(date);
  return CalendarCell.day(
    dayOfMonth: date.day,
    dateKey: dateMonth.dateKey(date.day),
    isInMonth: dateMonth == month,
  );
}

String monthAbbreviation(int month) => _monthNames[month - 1].substring(0, 3);

List<String> weekdayHeaders({int firstWeekday = DateTime.sunday}) =>
    _fromWeekday(_weekdayLetters, firstWeekday);

List<String> weekdayNames({int firstWeekday = DateTime.sunday}) =>
    _fromWeekday(_weekdayNames, firstWeekday);

List<String> _fromWeekday(List<String> week, int firstWeekday) => <String>[
  for (int i = 0; i < 7; i++) week[(firstWeekday - 1 + i) % 7],
];

String _pad2(int value) => value.toString().padLeft(2, '0');

String _pad4(int value) => value.toString().padLeft(4, '0');
