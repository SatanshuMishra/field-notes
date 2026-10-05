import 'dart:io';

import 'package:field_notes/data/media/blob_prefix.dart';
import 'package:field_notes/data/media/filesystem_media_store.dart';
import 'package:field_notes/data/sync/media/download_service.dart';
import 'package:field_notes/domain/models/media_blob.dart';
import 'package:field_notes/domain/models/media_kind.dart';
import 'package:field_notes/features/entry_cards/media/live_media.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';

typedef MediaFetcher = Future<bool> Function(String blobId);

typedef PosterLookup = Future<String?> Function(String blobId);

typedef OpenRecorder = Future<void> Function(String blobId);

typedef DownloadProgressLookup = Stream<MediaDownloadProgress>? Function(
  String blobId,
);

class SyncingMediaResolver implements MediaResolver, LiveMedia {
  SyncingMediaResolver({
    required this._inner,
    required this._store,
    required this._fetch,
    required this._posterOf,
    required this._recordOpen,
    required this._progressOf,
  });

  final MediaStoreResolver _inner;
  final FilesystemMediaStore _store;
  final MediaFetcher _fetch;
  final PosterLookup _posterOf;
  final OpenRecorder _recordOpen;
  final DownloadProgressLookup _progressOf;

  @override
  Stream<String> get arrivals => _store.arrivals;

  @override
  Stream<MediaDownloadProgress>? downloadProgress(String mediaId) =>
      _progressOf(mediaId);

  @override
  ResolvedMedia? resolved(String? mediaId) => _inner.resolved(mediaId);

  @override
  Future<ResolvedMedia> resolve(String? mediaId) async {
    final ResolvedMedia local = await _opened(await _inner.resolve(mediaId));
    if (local.isAvailable || mediaId == null || mediaId.isEmpty) {
      return local;
    }
    final MediaBlob? blob = isShortBlobReference(mediaId)
        ? await _store.blobByPrefix(mediaId)
        : await _store.blobById(mediaId);
    if (blob == null) {
      return local;
    }
    if (await _fetch(blob.id)) {
      final ResolvedMedia fetched = await _opened(
        await _inner.resolve(mediaId),
      );
      if (fetched.isAvailable) {
        return fetched;
      }
    }
    if (blob.kind != MediaKind.photo) {
      return const ResolvedMedia.missing();
    }
    return _poster(blob);
  }

  Future<ResolvedMedia> _poster(MediaBlob blob) async {
    final String? posterId = await _posterOf(blob.id);
    if (posterId == null) {
      return const ResolvedMedia.missing();
    }
    final ResolvedMedia poster = await _inner.resolve(posterId);
    if (poster.isAvailable) {
      return poster;
    }
    if (!await _fetch(posterId)) {
      return const ResolvedMedia.missing();
    }
    return _inner.resolve(posterId);
  }

  Future<ResolvedMedia> _opened(ResolvedMedia resolved) async {
    final MediaBlob? blob = resolved.blob;
    final File? file = resolved.file;
    if (resolved.isAvailable && blob != null && file != null) {
      await _recordOpen(blob.id);
    }
    return resolved;
  }
}
