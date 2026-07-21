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

const List<String> _weekdayShort = <String>[
  'Mo',
  'Tu',
  'We',
  'Th',
  'Fr',
  'Sa',
  'Su',
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
    required int this.dayOfMonth,
    required String this.dateKey,
  }) : isPadding = false;

  const CalendarCell.padding()
      : dayOfMonth = null,
        dateKey = null,
        isPadding = true;

  final int? dayOfMonth;
  final String? dateKey;
  final bool isPadding;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalendarCell &&
          runtimeType == other.runtimeType &&
          dayOfMonth == other.dayOfMonth &&
          dateKey == other.dateKey &&
          isPadding == other.isPadding;

  @override
  int get hashCode => Object.hash(dayOfMonth, dateKey, isPadding);
}

List<CalendarCell> monthGridCells(
  MonthRef month, {
  int firstWeekday = DateTime.sunday,
}) {
  final int firstWeekdayOfMonth = DateTime(month.year, month.month, 1).weekday;
  final int daysInMonth = DateTime(month.year, month.month + 1, 0).day;
  final int leading = (firstWeekdayOfMonth - firstWeekday + 7) % 7;

  final List<CalendarCell> cells = <CalendarCell>[
    for (int i = 0; i < leading; i++) const CalendarCell.padding(),
    for (int day = 1; day <= daysInMonth; day++)
      CalendarCell.day(dayOfMonth: day, dateKey: month.dateKey(day)),
  ];

  final int remainder = cells.length % 7;
  if (remainder != 0) {
    for (int i = 0; i < 7 - remainder; i++) {
      cells.add(const CalendarCell.padding());
    }
  }

  return List<CalendarCell>.unmodifiable(cells);
}

List<String> weekdayHeaders({int firstWeekday = DateTime.sunday}) {
  return <String>[
    for (int i = 0; i < 7; i++) _weekdayShort[(firstWeekday - 1 + i) % 7],
  ];
}

String _pad2(int value) => value.toString().padLeft(2, '0');

String _pad4(int value) => value.toString().padLeft(4, '0');
