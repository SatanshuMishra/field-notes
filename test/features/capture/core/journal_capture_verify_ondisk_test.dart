import 'dart:io';

import 'package:field_notes/data/database/app_database.dart' show AppDatabase;
import 'package:field_notes/data/journal/drift_journal_repository.dart';
import 'package:field_notes/data/media/filesystem_media_store.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/domain/services/media_store.dart';
import 'package:field_notes/features/capture/core/journal_capture_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'capture_test_support.dart';

const String _date = '2026-07-19';

class _CountingMediaStore implements MediaStore {
  _CountingMediaStore(this._inner);

  final MediaStore _inner;
  int putFileCalls = 0;

  @override
  Future<MediaBlob> putFile({
    required File source,
    required String mime,
    required MediaKind kind,
    int? width,
    int? height,
    int? durationMs,
  }) {
    putFileCalls++;
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
  Future<MediaBlob> putBytes({
    required List<int> bytes,
    required String mime,
    required MediaKind kind,
    int? width,
    int? height,
    int? durationMs,
  }) {
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
  Future<MediaBlob?> blobById(String id) => _inner.blobById(id);

  @override
  String absolutePath(MediaBlob blob) => _inner.absolutePath(blob);

  @override
  Future<int> collectGarbage() => _inner.collectGarbage();
}

void main() {
  late AppDatabase db;
  late Directory root;
  late Directory scratch;
  late DriftJournalRepository journal;
  late FilesystemMediaStore media;
  late _CountingMediaStore counting;
  late JournalCaptureService service;

  setUp(() async {
    db = newTestDatabase();
    root = await newTempMediaRoot();
    scratch = await Directory.systemTemp.createTemp('fn_ondisk');
    journal = DriftJournalRepository(db);
    media = FilesystemMediaStore(database: db, root: root);
    counting = _CountingMediaStore(media);
    service = JournalCaptureService(journal: journal, media: counting);
  });

  tearDown(() async {
    await db.close();
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
    if (await scratch.exists()) {
      await scratch.delete(recursive: true);
    }
  });

  test('a missing recorded file fails fast with the media-missing message',
      () async {
    final File absent = File(p.join(scratch.path, 'never_written.mp4'));

    await expectLater(
      service.capture(
        VoiceCaptureRequest(
          date: _date,
          audio: CaptureFile(file: absent, mime: 'audio/mp4'),
          durationMs: 4200,
        ),
      ),
      throwsA(
        isA<CaptureException>().having(
          (CaptureException e) => e.message,
          'message',
          mediaMissingMessage,
        ),
      ),
    );

    expect(counting.putFileCalls, 0);
    expect(await journal.activeDayForDate(_date), isNull);
  });

  test('an empty recorded file fails fast with the media-missing message',
      () async {
    final File empty = File(p.join(scratch.path, 'zero_bytes.mp4'));
    empty.writeAsBytesSync(<int>[]);

    await expectLater(
      service.capture(
        VideoCaptureRequest(
          date: _date,
          video: CaptureFile(file: empty, mime: 'video/mp4'),
          durationMs: 60000,
        ),
      ),
      throwsA(
        isA<CaptureException>().having(
          (CaptureException e) => e.message,
          'message',
          mediaMissingMessage,
        ),
      ),
    );

    expect(counting.putFileCalls, 0);
    expect(await journal.activeDayForDate(_date), isNull);
  });

  test(
      'a recorded path that is a directory fails with the media-missing '
      'message and never reaches putFile', () async {
    final Directory notAFile =
        Directory(p.join(scratch.path, 'a_directory.mp4'))..createSync();

    await expectLater(
      service.capture(
        VideoCaptureRequest(
          date: _date,
          video: CaptureFile(file: File(notAFile.path), mime: 'video/mp4'),
          durationMs: 60000,
        ),
      ),
      throwsA(
        isA<CaptureException>().having(
          (CaptureException e) => e.message,
          'message',
          mediaMissingMessage,
        ),
      ),
    );

    expect(counting.putFileCalls, 0);
    expect(await journal.activeDayForDate(_date), isNull);
  });

  test('a delayed async flush is awaited and then persisted', () async {
    final File flushing = File(p.join(scratch.path, 'flushes_late.mp4'));

    Future<void>.delayed(
      const Duration(milliseconds: 120),
      () => flushing.writeAsBytesSync(<int>[1, 2, 3, 4, 5]),
    );

    final CaptureResult result = await service.capture(
      VoiceCaptureRequest(
        date: _date,
        audio: CaptureFile(file: flushing, mime: 'audio/mp4'),
        durationMs: 4200,
      ),
    );

    expect(counting.putFileCalls, 1);
    final MediaBlob? blob = await media.blobById(result.entry.mediaId!);
    expect(blob, isNotNull);
    expect(blob!.kind, MediaKind.audio);
    expect(File(media.absolutePath(blob)).existsSync(), isTrue);
  });

  test('a file present and non-empty at call time persists in one putFile',
      () async {
    final File ready = File(p.join(scratch.path, 'ready.mp4'));
    ready.writeAsBytesSync(<int>[9, 8, 7, 6]);

    final CaptureResult result = await service.capture(
      VideoCaptureRequest(
        date: _date,
        video: CaptureFile(file: ready, mime: 'video/mp4'),
        durationMs: 60000,
      ),
    );

    expect(counting.putFileCalls, 1);
    final MediaBlob? blob = await media.blobById(result.entry.mediaId!);
    expect(blob, isNotNull);
    expect(blob!.kind, MediaKind.video);
    expect(result.entry.durationMs, 60000);
  });
}
