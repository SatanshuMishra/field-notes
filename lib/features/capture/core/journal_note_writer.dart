import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/repositories/journal_repository.dart';
import 'package:field_notes/domain/services/draft_store.dart';
import 'package:field_notes/domain/services/note_writer.dart';

import 'capture_date.dart';
import 'journal_capture_service.dart';

String normaliseNoteSource(String source) => source.trim();

class JournalNoteWriter implements NoteWriter {
  const JournalNoteWriter({required this.journal, required this.drafts});

  final JournalRepository journal;
  final DraftStore drafts;

  @override
  Future<NoteSaveResult> save({
    String? entryId,
    required String date,
    required String source,
    List<String> photoMediaIds = const <String>[],
    String? draftKey,
  }) async {
    if (!isCaptureDateKey(date)) {
      throw const NoteWriteException(invalidDateMessage);
    }
    final String text = normaliseNoteSource(source);
    if (text.isEmpty) {
      throw const NoteWriteException(blankTextMessage);
    }

    final Entry entry;
    try {
      entry = await journal.saveNote(
        entryId: entryId,
        date: date,
        source: text,
        photoMediaIds: photoMediaIds,
      );
    } catch (error) {
      throw NoteWriteException(entryWriteMessage, cause: error);
    }

    final String? key = draftKey ?? entryId;
    if (key != null) {
      await _deleteDraft(key);
    }

    return NoteSaveResult(entry: entry);
  }

  Future<void> _deleteDraft(String key) async {
    try {
      await drafts.delete(key);
    } on DraftWriteException {
      return;
    }
  }
}
