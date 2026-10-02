import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/repositories/journal_repository.dart';
import 'package:field_notes/domain/services/note_writer.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef FirstEntrySaved = ({Mood? mood, Entry? note});

class FirstEntry {
  const FirstEntry({required this._journal, required this._noteWriter});

  final JournalRepository _journal;
  final Future<NoteWriter> Function() _noteWriter;

  Future<FirstEntrySaved> read(String date) async {
    final Day? day = await _journal.watchDayForDate(date).first;
    final List<Entry> entries = await _journal.watchEntriesForDate(date).first;
    Entry? oldest;
    for (final Entry entry in entries) {
      if (entry.type == EntryType.text &&
          (oldest == null || entry.createdAt < oldest.createdAt)) {
        oldest = entry;
      }
    }
    return (mood: day?.mood, note: oldest);
  }

  Future<void> saveMood({required String date, required Mood mood}) =>
      _journal.setMoodForDate(date: date, mood: mood);

  Future<String> saveLine({
    required String date,
    required String? entryId,
    required String text,
  }) async {
    final NoteWriter writer = await _noteWriter();
    final NoteSaveResult saved = await writer.save(
      entryId: entryId,
      date: date,
      source: text,
    );
    return saved.entry.id;
  }

  Future<void> eraseLine(String entryId) => _journal.softDeleteEntry(entryId);
}

final Provider<FirstEntry> firstEntryProvider = Provider<FirstEntry>(
  (Ref ref) => FirstEntry(
    journal: ref.watch(journalRepositoryProvider),
    noteWriter: () => ref.read(noteWriterProvider.future),
  ),
);
