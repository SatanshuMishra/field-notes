import 'dart:io';

import '../../../data/media/blob_prefix.dart';
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

Future<MediaBlob?> blobForMediaReference(MediaStore store, String reference) {
  return isShortBlobReference(reference)
      ? store.blobByPrefix(reference)
      : store.blobById(reference);
}

abstract interface class MediaResolver {
  Future<ResolvedMedia> resolve(String? mediaId);

  ResolvedMedia? resolved(String? mediaId);
}

class MediaStoreResolver implements MediaResolver {
  MediaStoreResolver(this._store);

  final MediaStore _store;
  final Map<String, ResolvedMedia> _memo = <String, ResolvedMedia>{};
  final Map<String, Future<ResolvedMedia>> _inFlight =
      <String, Future<ResolvedMedia>>{};

  @override
  ResolvedMedia? resolved(String? mediaId) {
    if (mediaId == null || mediaId.isEmpty) {
      return const ResolvedMedia.missing();
    }
    return _memo[mediaId];
  }

  @override
  Future<ResolvedMedia> resolve(String? mediaId) {
    if (mediaId == null || mediaId.isEmpty) {
      return Future<ResolvedMedia>.value(const ResolvedMedia.missing());
    }
    final ResolvedMedia? memo = _memo[mediaId];
    if (memo != null) {
      return Future<ResolvedMedia>.value(memo);
    }
    final Future<ResolvedMedia>? pending = _inFlight[mediaId];
    if (pending != null) {
      return pending;
    }
    final Future<ResolvedMedia> started = _load(mediaId);
    _inFlight[mediaId] = started;
    return started;
  }

  Future<ResolvedMedia> _load(String mediaId) async {
    try {
      final ResolvedMedia result = await _lookup(mediaId);
      if (result.isAvailable) {
        _memo[mediaId] = result;
      }
      return result;
    } finally {
      _inFlight.remove(mediaId);
    }
  }

  Future<ResolvedMedia> _lookup(String mediaId) async {
    final MediaBlob? blob = await blobForMediaReference(_store, mediaId);
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
