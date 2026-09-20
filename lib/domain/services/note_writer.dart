import '../models/models.dart';

class NoteSaveResult {
  const NoteSaveResult({required this.entry});

  final Entry entry;
}

class NoteWriteException implements Exception {
  const NoteWriteException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'NoteWriteException: $message'
      : 'NoteWriteException: $message ($cause)';
}

abstract interface class NoteWriter {
  Future<NoteSaveResult> save({
    String? entryId,
    required String date,
    required String source,
    List<String> photoMediaIds = const <String>[],
    String? draftKey,
  });
}
