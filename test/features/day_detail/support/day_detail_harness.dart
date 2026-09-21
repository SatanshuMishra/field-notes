import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:field_notes/data/media/blob_prefix.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/repositories/journal_repository.dart';
import 'package:field_notes/domain/services/media_store.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart';

Widget dayDetailHarness(Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(body: Center(child: child)),
  );
}

Future<void> sendSystemBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
    (ByteData? _) {},
  );
  await tester.pumpAndSettle();
}

Entry entryOf({
  required EntryType type,
  String id = 'entry-1',
  String dayId = 'day-1',
  String? textContent,
  String? mediaId,
  int? durationMs,
}) {
  return Entry(
    id: id,
    dayId: dayId,
    type: type,
    textContent: textContent,
    mediaId: mediaId,
    durationMs: durationMs,
    createdAt: 0,
    updatedAt: 0,
  );
}

EntryPhoto photoOf({
  required String id,
  required String mediaId,
  int sortOrder = 0,
  String entryId = 'entry-1',
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

class FakeMediaResolver implements MediaResolver {
  FakeMediaResolver([Map<String, ResolvedMedia>? results])
      : _results = Map<String, ResolvedMedia>.of(
          results ?? const <String, ResolvedMedia>{},
        );

  final Map<String, ResolvedMedia> _results;

  @override
  ResolvedMedia? resolved(String? mediaId) => null;

  @override
  Future<ResolvedMedia> resolve(String? mediaId) async {
    if (mediaId == null) {
      return const ResolvedMedia.missing();
    }
    return _results[mediaId] ?? const ResolvedMedia.missing();
  }
}

class FakeMediaStore implements MediaStore {
  FakeMediaStore(this.root, {Map<String, MediaBlob>? blobs})
      : _blobs = Map<String, MediaBlob>.of(
          blobs ?? const <String, MediaBlob>{},
        );

  final Directory root;
  final Map<String, MediaBlob> _blobs;

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

class FakeJournalRepository implements JournalRepository {
  FakeJournalRepository({
    List<Entry> entries = const <Entry>[],
    Map<String, List<EntryPhoto>> photos = const <String, List<EntryPhoto>>{},
    this.day,
    this.entriesError,
  })  : _entries = List<Entry>.unmodifiable(entries),
        _photos = Map<String, List<EntryPhoto>>.of(photos);

  final List<Entry> _entries;
  final Map<String, List<EntryPhoto>> _photos;
  final Day? day;
  final Object? entriesError;

  final StreamController<List<Entry>> _entriesController =
      StreamController<List<Entry>>.broadcast();

  final List<String> deletedEntryIds = <String>[];
  final List<({String id, String textContent})> textUpdates =
      <({String id, String textContent})>[];
  final List<NoteSaveRecord> noteSaves = <NoteSaveRecord>[];

  Object? deleteError;
  Object? updateError;
  Object? saveError;

  @override
  Stream<List<Entry>> watchEntriesForDate(String date) async* {
    final Object? error = entriesError;
    if (error != null) {
      throw error;
    }
    yield _entries;
    yield* _entriesController.stream;
  }

  @override
  Stream<Day?> watchDayForDate(String date) async* {
    yield day;
  }

  @override
  Stream<List<EntryPhoto>> watchPhotosForEntry(String entryId) async* {
    yield List<EntryPhoto>.unmodifiable(
      _photos[entryId] ?? const <EntryPhoto>[],
    );
  }

  @override
  Future<void> softDeleteEntry(String id) async {
    final Object? error = deleteError;
    if (error != null) {
      throw error;
    }
    deletedEntryIds.add(id);
    _entriesController.add(<Entry>[
      for (final Entry entry in _entries)
        if (entry.id != id) entry,
    ]);
  }

  @override
  Future<void> updateEntryText({
    required String id,
    required String textContent,
  }) async {
    final Object? error = updateError;
    if (error != null) {
      throw error;
    }
    textUpdates.add((id: id, textContent: textContent));
  }

  @override
  Future<Entry> saveNote({
    String? entryId,
    required String date,
    required String source,
    required List<String> photoMediaIds,
  }) async {
    final Object? error = saveError;
    if (error != null) {
      throw error;
    }
    noteSaves.add((
      entryId: entryId,
      date: date,
      source: source,
      photoMediaIds: photoMediaIds,
    ));
    final Entry? existing = entryId == null
        ? null
        : _entries.cast<Entry?>().firstWhere(
              (Entry? entry) => entry?.id == entryId,
              orElse: () => null,
            );
    return Entry(
      id: entryId ?? 'entry-new',
      dayId: existing?.dayId ?? 'day-1',
      type: EntryType.text,
      textContent: source,
      createdAt: existing?.createdAt ?? 0,
      updatedAt: 1,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

typedef NoteSaveRecord = ({
  String? entryId,
  String date,
  String source,
  List<String> photoMediaIds,
});
