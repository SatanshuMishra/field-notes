import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

import 'package:field_notes/data/media/blob_prefix.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/services/media_store.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';

Widget cardHarness(
  Widget child, {
  double width = 360,
  MediaQueryData data = const MediaQueryData(),
}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: data,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: width, child: child),
      ),
    ),
  );
}

class FakeMediaResolver implements MediaResolver {
  FakeMediaResolver([Map<String, ResolvedMedia>? results])
      : _results = results ?? <String, ResolvedMedia>{};

  final Map<String, ResolvedMedia> _results;
  final Set<String> _memoized = <String>{};

  void set(String mediaId, ResolvedMedia media) => _results[mediaId] = media;

  void memoize(String mediaId) => _memoized.add(mediaId);

  @override
  ResolvedMedia? resolved(String? mediaId) =>
      mediaId != null && _memoized.contains(mediaId) ? _results[mediaId] : null;

  @override
  Future<ResolvedMedia> resolve(String? mediaId) async {
    if (mediaId == null) {
      return const ResolvedMedia.missing();
    }
    return _results[mediaId] ?? const ResolvedMedia.missing();
  }
}

class FakeMediaStore implements MediaStore {
  FakeMediaStore(this.root);

  final Directory root;
  final Map<String, MediaBlob> _blobs = <String, MediaBlob>{};

  void register(MediaBlob blob) => _blobs[blob.id] = blob;

  @override
  Future<MediaBlob?> blobById(String id) async => _blobs[id];

  @override
  Future<MediaBlob?> blobByPrefix(String prefix) async {
    final matches = _blobs.values
        .where((blob) => blob.id.startsWith(prefix))
        .toList(growable: false);
    return matches.length == 1 ? matches.first : null;
  }

  @override
  Future<String> uniquePrefixFor(String id) async {
    var length = photoRefPrefixLength;
    while (length < id.length) {
      final prefix = id.substring(0, length);
      final collides = _blobs.keys
          .any((other) => other != id && other.startsWith(prefix));
      if (!collides) {
        return prefix;
      }
      length = nextPrefixLength(length);
    }
    return id;
  }


  @override
  String absolutePath(MediaBlob blob) => p.join(root.path, blob.relPath);

  @override
  Future<MediaBlob> putBytes({
    required List<int> bytes,
    required String mime,
    required MediaKind kind,
    int? width,
    int? height,
    int? durationMs,
  }) =>
      throw UnimplementedError();

  @override
  Future<MediaBlob> putFile({
    required File source,
    required String mime,
    required MediaKind kind,
    int? width,
    int? height,
    int? durationMs,
  }) =>
      throw UnimplementedError();

  @override
  Future<int> collectGarbage() async => 0;
}

Entry entryOf({
  required EntryType type,
  String id = 'e1',
  String dayId = 'd1',
  String? textContent,
  String? mediaId,
  String? thumbnailMediaId,
  int? durationMs,
}) {
  return Entry(
    id: id,
    dayId: dayId,
    type: type,
    textContent: textContent,
    mediaId: mediaId,
    thumbnailMediaId: thumbnailMediaId,
    durationMs: durationMs,
    createdAt: 0,
    updatedAt: 0,
  );
}

EntryPhoto photoOf({
  required String id,
  required String mediaId,
  int sortOrder = 0,
  String entryId = 'e1',
}) {
  return EntryPhoto(
    id: id,
    entryId: entryId,
    mediaId: mediaId,
    sortOrder: sortOrder,
    createdAt: 0,
    updatedAt: 0,
  );
}

MediaBlob blobOf({
  required String id,
  required String relPath,
  MediaKind kind = MediaKind.photo,
}) {
  return MediaBlob(
    id: id,
    relPath: relPath,
    mime: 'application/octet-stream',
    kind: kind,
    bytes: 0,
    createdAt: 0,
  );
}

List<int> onePixelPngBytes() => base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAA'
      'C0lEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
    );
