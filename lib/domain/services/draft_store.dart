abstract interface class DraftStore {
  Future<String?> read(String key);

  Future<void> write(String key, String source);

  Future<void> delete(String key);
}

class DraftWriteException implements Exception {
  DraftWriteException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'DraftWriteException: $message'
      : 'DraftWriteException: $message ($cause)';
}
