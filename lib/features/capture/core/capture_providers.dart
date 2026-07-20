import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/state/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'journal_capture_service.dart';

final FutureProvider<CaptureService> captureServiceProvider =
    FutureProvider<CaptureService>((Ref ref) async {
  return JournalCaptureService(
    journal: ref.watch(journalRepositoryProvider),
    media: await ref.watch(mediaStoreProvider.future),
  );
});
