import 'dart:io';

import 'package:field_notes/data/database/app_database.dart' show AppDatabase;
import 'package:field_notes/data/journal/drift_journal_repository.dart';
import 'package:field_notes/data/media/blob_paths.dart';
import 'package:field_notes/data/media/filesystem_media_store.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/features/capture/core/journal_capture_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'capture_test_support.dart';

const String _date = '2026-07-19';

void main() {
  late AppDatabase db;
  late Directory root;
  late DriftJournalRepository journal;
  late FilesystemMediaStore media;
  late JournalCaptureService service;

  setUp(() async {
    db = newTestDatabase();
    root = await newTempMediaRoot();
    journal = DriftJournalRepository(db);
    media = FilesystemMediaStore(database: db, root: root);
    service = JournalCaptureService(journal: journal, media: media);
  });

  tearDown(() async {
    await db.close();
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  test('a voice capture stores an audio blob and links it to the entry',
      () async {
    final CaptureResult result = await service.capture(
      VoiceCaptureRequest(
        date: _date,
        audio: const CaptureBytes(bytes: <int>[1, 2, 3], mime: 'audio/mp4'),
        durationMs: 4200,
      ),
    );

    expect(result.entry.type, EntryType.voice);
    expect(result.entry.durationMs, 4200);

    final MediaBlob? blob = await media.blobById(result.entry.mediaId!);
    expect(blob, isNotNull);
    expect(blob!.kind, MediaKind.audio);
    expect(File(media.absolutePath(blob)).existsSync(), isTrue);
  });

  test('a video capture stores the video and its thumbnail photo blob',
      () async {
    final CaptureResult result = await service.capture(
      VideoCaptureRequest(
        date: _date,
        video: const CaptureBytes(bytes: <int>[9, 9, 9], mime: 'video/mp4'),
        thumbnail: const CaptureBytes(bytes: <int>[7, 7], mime: 'image/jpeg'),
        durationMs: 60000,
      ),
    );

    final MediaBlob? video = await media.blobById(result.entry.mediaId!);
    final MediaBlob? thumbnail =
        await media.blobById(result.entry.thumbnailMediaId!);

    expect(video!.kind, MediaKind.video);
    expect(thumbnail!.kind, MediaKind.photo);
    expect(result.entry.durationMs, 60000);
  });

  test('photos attach to the entry in order and identical bytes dedupe',
      () async {
    final CaptureResult result = await service.capture(
      TextCaptureRequest(
        date: _date,
        text: 'with memories',
        photos: const <CaptureMedia>[
          CaptureBytes(bytes: <int>[1, 1], mime: 'image/jpeg'),
          CaptureBytes(bytes: <int>[2, 2], mime: 'image/jpeg'),
          CaptureBytes(bytes: <int>[1, 1], mime: 'image/jpeg'),
        ],
      ),
    );

    expect(
      result.photos.map((EntryPhoto photo) => photo.sortOrder),
      <int>[0, 1, 2],
    );
    expect(result.photos[0].mediaId, result.photos[2].mediaId);
    expect(result.photos[0].mediaId, isNot(result.photos[1].mediaId));

    final List<EntryPhoto> stored = await journal.photosForEntry(
      result.entry.id,
    );
    expect(stored, hasLength(3));
  });

  test('a non-positive duration is rejected before any blob is written',
      () async {
    await expectLater(
      service.capture(
        VoiceCaptureRequest(
          date: _date,
          audio: const CaptureBytes(bytes: <int>[1], mime: 'audio/mp4'),
          durationMs: 0,
        ),
      ),
      throwsA(
        isA<CaptureException>().having(
          (CaptureException e) => e.message,
          'message',
          invalidDurationMessage,
        ),
      ),
    );

    expect(await journal.activeDayForDate(_date), isNull);
    expect(Directory(p.join(root.path, blobsSubdir)).existsSync(), isFalse);
  });

  test('a media write failure aborts the capture before any entry row',
      () async {
    final JournalCaptureService failing = JournalCaptureService(
      journal: journal,
      media: FailingMediaStore(media, failPutBytes: true),
    );

    await expectLater(
      failing.capture(
        VoiceCaptureRequest(
          date: _date,
          audio: const CaptureBytes(bytes: <int>[1], mime: 'audio/mp4'),
          durationMs: 1000,
        ),
      ),
      throwsA(
        isA<CaptureException>()
            .having(
              (CaptureException e) => e.message,
              'message',
              mediaWriteMessage,
            )
            .having(
              (CaptureException e) => e.isPartiallySaved,
              'isPartiallySaved',
              isFalse,
            ),
      ),
    );

    expect(await journal.activeDayForDate(_date), isNull);
  });

  test('an entry-row failure leaves only an orphan blob that GC reclaims',
      () async {
    final JournalCaptureService failing = JournalCaptureService(
      journal: FailingJournalRepository(journal, failCreateEntry: true),
      media: media,
    );

    await expectLater(
      failing.capture(
        VoiceCaptureRequest(
          date: _date,
          audio: const CaptureBytes(bytes: <int>[5, 5, 5], mime: 'audio/mp4'),
          durationMs: 1000,
        ),
      ),
      throwsA(
        isA<CaptureException>().having(
          (CaptureException e) => e.message,
          'message',
          entryWriteMessage,
        ),
      ),
    );

    final Day? day = await journal.activeDayForDate(_date);
    expect(await journal.entriesForDay(day!.id), isEmpty);
    expect(await media.collectGarbage(), 1);
  });

  test('a photo-attach failure never loses the saved entry', () async {
    final JournalCaptureService failing = JournalCaptureService(
      journal: FailingJournalRepository(journal, failAddPhoto: true),
      media: media,
    );

    late CaptureException raised;
    try {
      await failing.capture(
        TextCaptureRequest(
          date: _date,
          text: 'kept safe',
          photos: const <CaptureMedia>[
            CaptureBytes(bytes: <int>[3, 3], mime: 'image/jpeg'),
          ],
        ),
      );
      fail('expected a CaptureException');
    } on CaptureException catch (error) {
      raised = error;
    }

    expect(raised.message, photoAttachMessage);
    expect(raised.isPartiallySaved, isTrue);

    final Day? day = await journal.activeDayForDate(_date);
    final List<Entry> stored = await journal.entriesForDay(day!.id);
    expect(stored.single.id, raised.savedEntryId);
    expect(stored.single.textContent, 'kept safe');
  });
}
