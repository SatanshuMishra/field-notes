import 'package:field_notes/data/media/media_duration.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/domain/services/note_writer.dart';
import 'package:field_notes/state/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'journal_capture_service.dart';
import 'journal_note_writer.dart';

final Provider<MediaDurationProbe> mediaDurationProbeProvider =
    Provider<MediaDurationProbe>(
  (Ref ref) => const PlatformMediaDurationProbe(),
);

final FutureProvider<CaptureService> captureServiceProvider =
    FutureProvider<CaptureService>((Ref ref) async {
  return JournalCaptureService(
    journal: ref.watch(journalRepositoryProvider),
    media: await ref.watch(mediaStoreProvider.future),
    durationProbe: ref.watch(mediaDurationProbeProvider),
  );
});

final FutureProvider<NoteWriter> noteWriterProvider =
    FutureProvider<NoteWriter>((Ref ref) async {
  return JournalNoteWriter(
    journal: ref.watch(journalRepositoryProvider),
    drafts: await ref.watch(draftStoreProvider.future),
  );
});
