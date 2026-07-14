class MediaWriteException implements Exception {
  MediaWriteException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'MediaWriteException: $message'
      : 'MediaWriteException: $message ($cause)';
}

class MediaReadException implements Exception {
  MediaReadException(this.message);

  final String message;

  @override
  String toString() => 'MediaReadException: $message';
}
