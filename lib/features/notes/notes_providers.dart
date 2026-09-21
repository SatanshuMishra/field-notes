import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/data/media/blob_prefix.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/domain/services/media_store.dart';
import 'package:field_notes/features/capture/photo/image_picker_photo_picker.dart';
import 'package:field_notes/features/capture/photo/photo_picker.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/state/state.dart';

final Provider<PhotoPicker> notePhotoPickerProvider =
    Provider<PhotoPicker>((Ref ref) => ImagePickerPhotoPicker());

final FutureProvider<MediaResolver> notesMediaResolverProvider =
    FutureProvider<MediaResolver>((Ref ref) async {
  return MediaStoreResolver(await ref.watch(mediaStoreProvider.future));
});

final FutureProvider<NotePhotoStore> notePhotoStoreProvider =
    FutureProvider<NotePhotoStore>((Ref ref) async {
  return NotePhotoStore(await ref.watch(mediaStoreProvider.future));
});

class NotePhotoStore {
  const NotePhotoStore(this._media);

  final MediaStore _media;

  Future<String> importPhoto(CaptureMedia photo) async {
    final MediaBlob blob = await switch (photo) {
      CaptureBytes(:final List<int> bytes) => _media.putBytes(
          bytes: bytes,
          mime: photo.mime,
          kind: MediaKind.photo,
          width: photo.width,
          height: photo.height,
        ),
      CaptureFile(:final file) => _media.putFile(
          source: file,
          mime: photo.mime,
          kind: MediaKind.photo,
          width: photo.width,
          height: photo.height,
        ),
    };
    return _media.uniquePrefixFor(blob.id);
  }

  Future<List<String>> mediaIdsReferencedBy(String source) async {
    final Set<String> ids = <String>{};
    for (final String prefix in blobPrefixesIn(source)) {
      final MediaBlob? blob = await _media.blobByPrefix(prefix);
      if (blob != null) {
        ids.add(blob.id);
      }
    }
    return List<String>.unmodifiable(ids);
  }
}

Future<List<String>> notePhotoMediaIds(
  String source,
  Future<NotePhotoStore> Function() store,
) async {
  if (blobPrefixesIn(source).isEmpty) {
    return const <String>[];
  }
  return (await store()).mediaIdsReferencedBy(source);
}
