import 'dart:io';

import 'package:drift/native.dart';
import 'package:field_notes/data/database/app_database.dart' show AppDatabase;
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/repositories/journal_repository.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/domain/services/draft_store.dart';
import 'package:field_notes/domain/services/media_store.dart';
import 'package:field_notes/domain/services/note_writer.dart';
import 'package:flutter/material.dart';

AppDatabase newTestDatabase() => AppDatabase(NativeDatabase.memory());

const Duration draftIdleDebounceForTest = Duration(milliseconds: 450);

Future<Directory> newTempMediaRoot() =>
    Directory.systemTemp.createTemp('fn_capture');

Widget captureHarness(Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(body: Center(child: child)),
  );
}

class FailingJournalRepository implements JournalRepository {
  FailingJournalRepository(
    this._inner, {
    this.failCreateEntry = false,
    this.failAddPhoto = false,
  });

  final JournalRepository _inner;
  final bool failCreateEntry;
  final bool failAddPhoto;

  @override
  Future<Day?> activeDayForDate(String date) => _inner.activeDayForDate(date);

  @override
  Future<Day> ensureDayForDate(String date) => _inner.ensureDayForDate(date);

  @override
  Future<Entry> createEntry({
    required String dayId,
    required EntryType type,
    String? textContent,
    String? mediaId,
    String? thumbnailMediaId,
    int? durationMs,
  }) {
    if (failCreateEntry) {
      return Future<Entry>.error(StateError('createEntry failed'));
    }
    return _inner.createEntry(
      dayId: dayId,
      type: type,
      textContent: textContent,
      mediaId: mediaId,
      thumbnailMediaId: thumbnailMediaId,
      durationMs: durationMs,
    );
  }

  @override
  Future<EntryPhoto> addPhoto({
    required String entryId,
    required String mediaId,
    required int sortOrder,
  }) {
    if (failAddPhoto) {
      return Future<EntryPhoto>.error(StateError('addPhoto failed'));
    }
    return _inner.addPhoto(
      entryId: entryId,
      mediaId: mediaId,
      sortOrder: sortOrder,
    );
  }

  @override
  Future<List<Entry>> entriesForDay(String dayId) => _inner.entriesForDay(dayId);

  @override
  Future<List<EntryPhoto>> photosForEntry(String entryId) =>
      _inner.photosForEntry(entryId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FailingMediaStore implements MediaStore {
  FailingMediaStore(this._inner, {this.failPutBytes = false});

  final MediaStore _inner;
  final bool failPutBytes;

  @override
  Future<MediaBlob> putBytes({
    required List<int> bytes,
    required String mime,
    required MediaKind kind,
    int? width,
    int? height,
    int? durationMs,
  }) {
    if (failPutBytes) {
      return Future<MediaBlob>.error(
        const FileSystemException('no space left on device'),
      );
    }
    return _inner.putBytes(
      bytes: bytes,
      mime: mime,
      kind: kind,
      width: width,
      height: height,
      durationMs: durationMs,
    );
  }

  @override
  Future<MediaBlob> putFile({
    required File source,
    required String mime,
    required MediaKind kind,
    int? width,
    int? height,
    int? durationMs,
  }) {
    return _inner.putFile(
      source: source,
      mime: mime,
      kind: kind,
      width: width,
      height: height,
      durationMs: durationMs,
    );
  }

  @override
  Future<MediaBlob?> blobById(String id) => _inner.blobById(id);

  @override
  Future<MediaBlob?> blobByPrefix(String prefix) => _inner.blobByPrefix(prefix);

  @override
  Future<String> uniquePrefixFor(String id) => _inner.uniquePrefixFor(id);


  @override
  String absolutePath(MediaBlob blob) => _inner.absolutePath(blob);

  @override
  Future<int> collectGarbage() => _inner.collectGarbage();
}

class FakeCaptureService implements CaptureService {
  FakeCaptureService({this.failure});

  final CaptureException? failure;
  final List<CaptureRequest> requests = <CaptureRequest>[];

  @override
  Future<CaptureResult> capture(CaptureRequest request) async {
    requests.add(request);
    final CaptureException? error = failure;
    if (error != null) {
      throw error;
    }
    final Day day = Day(
      id: 'day-1',
      date: request.date,
      createdAt: 0,
      updatedAt: 0,
    );
    final Entry entry = Entry(
      id: 'entry-1',
      dayId: day.id,
      type: request.type,
      textContent: request is TextCaptureRequest ? request.text : null,
      createdAt: 0,
      updatedAt: 0,
    );
    return CaptureResult(day: day, entry: entry, photos: const <EntryPhoto>[]);
  }
}

typedef NoteSaveCall = ({
  String? entryId,
  String date,
  String source,
  List<String> photoMediaIds,
  String? draftKey,
});

class FakeNoteWriter implements NoteWriter {
  FakeNoteWriter({this.failure, this.delay, this.entryId = 'entry-1'});

  final NoteWriteException? failure;
  final Duration? delay;
  final String entryId;
  final List<NoteSaveCall> saves = <NoteSaveCall>[];

  @override
  Future<NoteSaveResult> save({
    String? entryId,
    required String date,
    required String source,
    List<String> photoMediaIds = const <String>[],
    String? draftKey,
  }) async {
    saves.add((
      entryId: entryId,
      date: date,
      source: source,
      photoMediaIds: photoMediaIds,
      draftKey: draftKey,
    ));
    final Duration? wait = delay;
    if (wait != null) {
      await Future<void>.delayed(wait);
    }
    final NoteWriteException? error = failure;
    if (error != null) {
      throw error;
    }
    return NoteSaveResult(
      entry: Entry(
        id: entryId ?? this.entryId,
        dayId: 'day-1',
        type: EntryType.text,
        textContent: source,
        createdAt: 0,
        updatedAt: 0,
      ),
    );
  }
}

class FakeDraftStore implements DraftStore {
  FakeDraftStore({Map<String, String>? drafts, this.readDelay})
      : drafts = Map<String, String>.of(drafts ?? const <String, String>{});

  final Map<String, String> drafts;
  final Duration? readDelay;
  final List<({String key, String source})> writes =
      <({String key, String source})>[];
  final List<String> deletes = <String>[];
  Object? writeError;

  @override
  Future<String?> read(String key) async {
    final Duration? delay = readDelay;
    if (delay != null) {
      await Future<void>.delayed(delay);
    }
    return drafts[key];
  }

  @override
  Future<void> write(String key, String source) async {
    final Object? error = writeError;
    if (error != null) {
      throw error;
    }
    writes.add((key: key, source: source));
    drafts[key] = source;
  }

  @override
  Future<void> delete(String key) async {
    deletes.add(key);
    drafts.remove(key);
  }
}
