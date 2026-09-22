import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/features/capture/photo/photo_picker.dart';

import '../notes_providers.dart';

typedef PhotoImporter = Future<List<String>> Function();

const String composerPhotoFailedMessage =
    'Could not add that photo. Please try again.';

Future<List<String>> importNotePhotos(WidgetRef ref) async {
  final PhotoPicker picker = ref.read(notePhotoPickerProvider);
  final List<CaptureMedia> picked = await picker.pickFromLibrary();
  if (picked.isEmpty) {
    return const <String>[];
  }
  final NotePhotoStore store = await ref.read(notePhotoStoreProvider.future);
  final List<String> references = <String>[];
  for (final CaptureMedia photo in picked) {
    references.add(await store.importPhoto(photo));
  }
  return List<String>.unmodifiable(references);
}
