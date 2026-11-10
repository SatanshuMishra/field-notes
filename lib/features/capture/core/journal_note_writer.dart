import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/notes/markdown/markdown.dart'
    show MdBlock, MdBlockKind, parseNoteTree, plainTextOfTree;
import 'package:field_notes/domain/repositories/journal_repository.dart';
import 'package:field_notes/domain/services/draft_store.dart';
import 'package:field_notes/domain/services/note_limits.dart';
import 'package:field_notes/domain/services/note_writer.dart';
import 'package:field_notes/features/note_engine/capabilities.dart'
    show tablesEnabled;

import 'capture_date.dart';
import 'journal_capture_service.dart';

const String _titledSourceMarker = '\uE000';
const int _lineFeed = 0x0A;
const int _carriageReturn = 0x0D;
const int _space = 0x20;
const int _tab = 0x09;

String normaliseNoteSource(String source) => source.trim();

final class NoteSourceParts {
  const NoteSourceParts({
    required this.title,
    required this.body,
    this.lead = '',
  });

  final String title;
  final String body;
  final String lead;

  bool get carriesTitle => lead.isNotEmpty;
}

String titledNoteSource({required String title, required String body}) =>
    '$_titledSourceMarker${title.trim()}\n$body';

NoteSourceParts readTitledNoteSource(String source) {
  if (!source.startsWith(_titledSourceMarker)) {
    return NoteSourceParts(title: '', body: source);
  }
  final int lineFeed = source.indexOf('\n');
  final int titleEnd = lineFeed < 0 ? source.length : lineFeed;
  final int bodyStart = lineFeed < 0 ? source.length : lineFeed + 1;
  return NoteSourceParts(
    title: source.substring(_titledSourceMarker.length, titleEnd).trim(),
    body: source.substring(bodyStart),
    lead: source.substring(0, bodyStart),
  );
}

NoteSourceParts splitNoteSource(String source) {
  final NoteSourceParts titled = readTitledNoteSource(source);
  return titled.carriesTitle ? titled : _liftLeadingHeading(source);
}

NoteSourceParts _liftLeadingHeading(String source) {
  final Iterable<MdBlock> written = parseNoteTree(
    source,
    tables: tablesEnabled,
  ).blocks.where((MdBlock block) => block.kind != MdBlockKind.blankLine);
  final MdBlock? first = written.firstOrNull;
  if (first == null || first.kind != MdBlockKind.heading) {
    return NoteSourceParts(title: '', body: source);
  }
  final int headingEnd = first.sourceRange.end;
  final String heading = source.substring(first.sourceRange.start, headingEnd);
  final int bodyStart = _startOfNextWrittenLine(source, headingEnd);
  return NoteSourceParts(
    title: plainTextOfTree(
      parseNoteTree(heading, tables: tablesEnabled),
      heading,
    ).trim(),
    body: source.substring(bodyStart),
    lead: source.substring(0, bodyStart),
  );
}

int _startOfNextWrittenLine(String source, int from) {
  int lineStart = from;
  for (int at = from; at < source.length; at++) {
    final int unit = source.codeUnitAt(at);
    if (unit == _lineFeed || unit == _carriageReturn) {
      lineStart = at + 1;
    } else if (unit != _space && unit != _tab) {
      return lineStart;
    }
  }
  return source.length;
}

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
    final NoteSourceParts parts = readTitledNoteSource(source);
    final String text = normaliseNoteSource(parts.body);
    if (text.isEmpty) {
      throw const NoteWriteException(blankTextMessage);
    }
    if (!noteFitsSync('${parts.title}$text')) {
      throw const NoteWriteException(noteTooLongMessage);
    }

    final Entry entry;
    try {
      entry = await journal.saveNote(
        entryId: entryId,
        date: date,
        source: text,
        photoMediaIds: photoMediaIds,
        title: parts.carriesTitle ? parts.title : null,
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
