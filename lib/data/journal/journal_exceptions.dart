class DuplicateDayException implements Exception {
  const DuplicateDayException(this.date);

  final String date;

  @override
  String toString() =>
      'DuplicateDayException: an active day already exists for $date';
}

class MalformedRowException implements Exception {
  const MalformedRowException(this.message);

  final String message;

  @override
  String toString() => 'MalformedRowException: $message';
}
