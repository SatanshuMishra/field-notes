import 'dart:io';

import '../../../domain/models/media_blob.dart';
import '../../../domain/services/media_store.dart';

enum MediaAvailability { available, missing }

class ResolvedMedia {
  const ResolvedMedia.available({required this.blob, required this.file})
      : availability = MediaAvailability.available;

  const ResolvedMedia.missing()
      : availability = MediaAvailability.missing,
        blob = null,
        file = null;

  final MediaAvailability availability;
  final MediaBlob? blob;
  final File? file;

  bool get isAvailable => availability == MediaAvailability.available;
}

abstract interface class MediaResolver {
  Future<ResolvedMedia> resolve(String? mediaId);
}

class MediaStoreResolver implements MediaResolver {
  const MediaStoreResolver(this._store);

  final MediaStore _store;

  @override
  Future<ResolvedMedia> resolve(String? mediaId) async {
    if (mediaId == null || mediaId.isEmpty) {
      return const ResolvedMedia.missing();
    }
    final MediaBlob? blob = await _store.blobById(mediaId);
    if (blob == null) {
      return const ResolvedMedia.missing();
    }
    final File file = File(_store.absolutePath(blob));
    if (!await file.exists()) {
      return const ResolvedMedia.missing();
    }
    return ResolvedMedia.available(blob: blob, file: file);
  }
}
