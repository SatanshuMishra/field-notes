import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/data/media/blob_prefix.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/domain/services/media_store.dart';
import 'package:field_notes/features/capture/photo/photo_picker.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';

final String photoIdA = 'a1b2c3d4e5f6${'0' * 52}';
final String photoIdB = 'b2c3d4e5f6a1${'1' * 52}';
final String photoIdC = 'c3d4e5f6a1b2${'2' * 52}';

String prefixOf(String id) => id.substring(0, 12);

String photoLine(
  String id, {
  String caption = '',
  MdPhotoSide side = MdPhotoSide.right,
  MdPhotoSize size = MdPhotoSize.medium,
}) {
  return canonicalPhotoLine(
    prefixOf(id),
    caption,
    MdPhotoPlacement(side: side, size: size),
  );
}

MediaBlob photoBlob(String id, {int? width = 1200, int? height = 800}) {
  return MediaBlob(
    id: id,
    relPath: 'blobs/$id.jpg',
    mime: 'image/jpeg',
    kind: MediaKind.photo,
    bytes: 1,
    createdAt: 0,
    width: width,
    height: height,
  );
}

ResolvedMedia availablePhoto(
  String id, {
  int? width = 1200,
  int? height = 800,
}) {
  return ResolvedMedia.available(
    blob: photoBlob(id, width: width, height: height),
    file: File('${Directory.systemTemp.path}/field-notes-absent/$id.jpg'),
  );
}

class FakeNoteMediaResolver implements MediaResolver {
  FakeNoteMediaResolver([Map<String, ResolvedMedia>? results])
    : _results = <String, ResolvedMedia>{...?results};

  final Map<String, ResolvedMedia> _results;
  final Set<String> _memoized = <String>{};

  void memoizeAll() => _memoized.addAll(_results.keys);

  @override
  ResolvedMedia? resolved(String? mediaId) =>
      mediaId != null && _memoized.contains(mediaId) ? _results[mediaId] : null;

  @override
  Future<ResolvedMedia> resolve(String? mediaId) async =>
      _results[mediaId] ?? const ResolvedMedia.missing();
}

class FakeNoteMediaStore implements MediaStore {
  FakeNoteMediaStore({List<String> assignIds = const <String>[]})
    : _assign = <String>[...assignIds];

  final List<String> _assign;
  final Map<String, MediaBlob> _blobs = <String, MediaBlob>{};
  final List<String> prefixLookups = <String>[];

  void register(MediaBlob blob) => _blobs[blob.id] = blob;

  List<MediaBlob> get blobs => List<MediaBlob>.unmodifiable(_blobs.values);

  MediaBlob _put(String mime, int bytes, int? width, int? height) {
    final MediaBlob blob = MediaBlob(
      id: _assign.removeAt(0),
      relPath: 'blobs/${_blobs.length}',
      mime: mime,
      kind: MediaKind.photo,
      bytes: bytes,
      createdAt: 0,
      width: width,
      height: height,
    );
    _blobs[blob.id] = blob;
    return blob;
  }

  @override
  Future<MediaBlob> putBytes({
    required List<int> bytes,
    required String mime,
    required MediaKind kind,
    int? width,
    int? height,
    int? durationMs,
  }) async => _put(mime, bytes.length, width, height);

  @override
  Future<MediaBlob> putFile({
    required File source,
    required String mime,
    required MediaKind kind,
    int? width,
    int? height,
    int? durationMs,
  }) async => _put(mime, 1, width, height);

  @override
  Future<MediaBlob?> blobById(String id) async => _blobs[id];

  @override
  Future<MediaBlob?> blobByPrefix(String prefix) async {
    prefixLookups.add(prefix);
    final List<MediaBlob> matches = _blobs.values
        .where((MediaBlob blob) => blob.id.startsWith(prefix))
        .toList(growable: false);
    return matches.length == 1 ? matches.first : null;
  }

  @override
  Future<String> uniquePrefixFor(String id) async {
    int length = photoRefPrefixLength;
    while (length < id.length) {
      final String prefix = id.substring(0, length);
      if (!_blobs.keys.any(
        (String other) => other != id && other.startsWith(prefix),
      )) {
        return prefix;
      }
      length = nextPrefixLength(length);
    }
    return id;
  }

  @override
  String absolutePath(MediaBlob blob) =>
      '${Directory.systemTemp.path}/field-notes-absent/${blob.relPath}';

  @override
  Future<int> collectGarbage() async => 0;
}

class FakePhotoImporter {
  FakePhotoImporter({List<List<String>>? results, this.error})
    : _results = <List<String>>[...?results];

  final List<List<String>> _results;
  final Object? error;
  int calls = 0;

  Future<List<String>> call() async {
    calls++;
    final Object? failure = error;
    if (failure != null) {
      throw failure;
    }
    return _results.isEmpty ? const <String>[] : _results.removeAt(0);
  }
}

const PhotoPickException denialError = PhotoPickException(
  photoLibraryErrorMessage,
);

Widget notesHarness(Widget child, {double width = 600}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: width, child: child),
      ),
    ),
  );
}

TextSelection caretAt(int offset) => TextSelection.collapsed(offset: offset);

void expectTargetAtLeast48(WidgetTester tester, Finder finder) {
  final Size size = tester.getSize(finder);
  expect(size.width, greaterThanOrEqualTo(48), reason: '$finder width');
  expect(size.height, greaterThanOrEqualTo(48), reason: '$finder height');
}
