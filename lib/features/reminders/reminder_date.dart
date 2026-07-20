String reminderDateKey(DateTime day) {
  final String year = day.year.toString().padLeft(4, '0');
  final String month = day.month.toString().padLeft(2, '0');
  final String dayOfMonth = day.day.toString().padLeft(2, '0');
  return '$year-$month-$dayOfMonth';
}
