import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/repositories/journal_repository.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/domain/services/media_store.dart';

import 'capture_date.dart';

const String blankTextMessage = 'Add a few words before saving your note.';
const String invalidDateMessage =
    'That day could not be identified. Nothing was saved.';
const String unsupportedCaptureMessage =
    'That capture is not available yet. Nothing was saved.';

class JournalCaptureService implements CaptureService {
  const JournalCaptureService({required this.journal, required this.media});

  final JournalRepository journal;
  final MediaStore media;

  @override
  Future<CaptureResult> capture(CaptureRequest request) async {
    if (!isCaptureDateKey(request.date)) {
      throw const CaptureException(invalidDateMessage);
    }
    if (request is! TextCaptureRequest) {
      throw const CaptureException(unsupportedCaptureMessage);
    }

    final String text = _resolveText(request);
    final Day day = await journal.ensureDayForDate(request.date);
    final Entry entry = await journal.createEntry(
      dayId: day.id,
      type: request.type,
      textContent: text,
    );

    return CaptureResult(day: day, entry: entry, photos: const <EntryPhoto>[]);
  }

  String _resolveText(TextCaptureRequest request) {
    final String text = request.text.trim();
    if (text.isEmpty) {
      throw const CaptureException(blankTextMessage);
    }
    return text;
  }
}
