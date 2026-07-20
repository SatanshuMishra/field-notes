final RegExp _dateKeyPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

String captureDateKey(DateTime moment) {
  final DateTime local = moment.toLocal();
  final String year = local.year.toString().padLeft(4, '0');
  final String month = local.month.toString().padLeft(2, '0');
  final String day = local.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

bool isCaptureDateKey(String value) => _dateKeyPattern.hasMatch(value);
