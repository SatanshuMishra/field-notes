import 'package:field_notes/features/capture/core/capture_date.dart';

const List<String> _weekdayNames = <String>[
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

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

class DayDetailHeading {
  const DayDetailHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DayDetailHeading &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          subtitle == other.subtitle;

  @override
  int get hashCode => Object.hash(title, subtitle);

  @override
  String toString() => 'DayDetailHeading(title: $title, subtitle: $subtitle)';
}

DayDetailHeading dayDetailHeadingFor(String date) {
  final DateTime? parsed = _parseDateKey(date);
  if (parsed == null) {
    return DayDetailHeading(title: date, subtitle: '');
  }
  final String weekday = _weekdayNames[parsed.weekday - 1];
  final String month = _monthNames[parsed.month - 1];
  return DayDetailHeading(
    title: '$weekday, $month ${parsed.day}',
    subtitle: '${parsed.year}',
  );
}

DateTime? _parseDateKey(String date) {
  if (!isCaptureDateKey(date)) {
    return null;
  }
  final int? year = int.tryParse(date.substring(0, 4));
  final int? month = int.tryParse(date.substring(5, 7));
  final int? day = int.tryParse(date.substring(8, 10));
  if (year == null || month == null || day == null) {
    return null;
  }
  final DateTime candidate = DateTime(year, month, day);
  if (candidate.year != year ||
      candidate.month != month ||
      candidate.day != day) {
    return null;
  }
  return candidate;
}
