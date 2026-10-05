class ExportException implements Exception {
  const ExportException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'ExportException: $message'
      : 'ExportException: $message ($cause)';
}
