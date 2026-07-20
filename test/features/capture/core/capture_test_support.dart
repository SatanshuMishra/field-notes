import 'dart:io';

import 'package:drift/native.dart';
import 'package:field_notes/data/database/app_database.dart' show AppDatabase;
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/repositories/journal_repository.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/domain/services/media_store.dart';
import 'package:flutter/material.dart';

AppDatabase newTestDatabase() => AppDatabase(NativeDatabase.memory());

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
