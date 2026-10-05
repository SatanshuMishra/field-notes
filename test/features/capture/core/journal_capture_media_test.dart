import 'dart:io';

import 'package:field_notes/data/database/app_database.dart' show AppDatabase;
import 'package:field_notes/data/journal/drift_journal_repository.dart';
import 'package:field_notes/data/media/blob_paths.dart';
import 'package:field_notes/data/media/filesystem_media_store.dart';
import 'package:field_notes/data/media/media_duration.dart';
import 'package:field_notes/data/sync/change_recorder.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/features/capture/core/journal_capture_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'capture_test_support.dart';

const String _date = '2026-07-19';

typedef _ProbeCall = ({String path, MediaKind kind});

class _FakeDurationProbe implements MediaDurationProbe {
  _FakeDurationProbe(this._measure);

  final Future<Duration?> Function() _measure;
  final List<_ProbeCall> calls = <_ProbeCall>[];

  @override
  Future<Duration?> duration({required File file, required MediaKind kind}) {
    calls.add((path: file.path, kind: kind));
    return _measure();
  }
}

const int _playerId = 11;

class _MeasuringVideoPlatform extends VideoPlayerPlatform {
  _MeasuringVideoPlatform(this._duration);

  final Duration _duration;
  final List<String?> openedUris = <String?>[];
  final List<int> disposedPlayers = <int>[];

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    openedUris.add(options.dataSource.uri);
    return _playerId;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => Stream<VideoEvent>.value(
        VideoEvent(
          eventType: VideoEventType.initialized,
          size: const Size(1920, 1080),
          duration: _duration,
        ),
      );

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> play(int playerId) async {}

  @override
  Future<void> pause(int playerId) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Future<void> dispose(int playerId) async => disposedPlayers.add(playerId);
}

void main() {
  late AppDatabase db;
  late Directory root;
  late DriftJournalRepository journal;
  late FilesystemMediaStore media;
  late JournalCaptureService service;

  setUp(() async {
    db = newTestDatabase();
    root = await newTempMediaRoot();
    final ChangeRecorder recorder = ChangeRecorder(db);
    journal = DriftJournalRepository(db, recorder: recorder);
    media = FilesystemMediaStore(database: db, recorder: recorder, root: root);
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

  test("the stored duration is the finished file's duration", () async {
    final _FakeDurationProbe probe = _FakeDurationProbe(
      () async => const Duration(milliseconds: 8990),
    );
    final JournalCaptureService probed = JournalCaptureService(
      journal: journal,
      media: media,
      durationProbe: probe,
    );

    final CaptureResult video = await probed.capture(
      VideoCaptureRequest(
        date: _date,
        video: const CaptureBytes(bytes: <int>[9, 0, 5], mime: 'video/mp4'),
        thumbnail: const CaptureBytes(bytes: <int>[7, 7], mime: 'image/jpeg'),
        durationMs: 9050,
      ),
    );
    final CaptureResult voice = await probed.capture(
      VoiceCaptureRequest(
        date: _date,
        audio: const CaptureBytes(bytes: <int>[4, 0, 5], mime: 'audio/mp4'),
        durationMs: 9050,
      ),
    );

    expect(video.entry.durationMs, 8990);
    expect(voice.entry.durationMs, 8990);
    final List<Entry> stored = await journal.entriesForDay(video.day.id);
    expect(
      stored.map((Entry entry) => entry.durationMs),
      <int>[8990, 8990],
    );
    final MediaBlob? videoBlob = await media.blobById(video.entry.mediaId!);
    final MediaBlob? voiceBlob = await media.blobById(voice.entry.mediaId!);
    expect(probe.calls, <_ProbeCall>[
      (path: media.absolutePath(videoBlob!), kind: MediaKind.video),
      (path: media.absolutePath(voiceBlob!), kind: MediaKind.audio),
    ]);
  });

  testWidgets(
      'the platform probe reads a saved video from the video player '
      'and releases it', (WidgetTester tester) async {
    final VideoPlayerPlatform previous = VideoPlayerPlatform.instance;
    final _MeasuringVideoPlatform platform = _MeasuringVideoPlatform(
      const Duration(milliseconds: 8990),
    );
    VideoPlayerPlatform.instance = platform;
    addTearDown(() => VideoPlayerPlatform.instance = previous);
    final JournalCaptureService probed = JournalCaptureService(
      journal: journal,
      media: media,
      durationProbe: const PlatformMediaDurationProbe(),
    );

    final CaptureResult? result = await tester.runAsync(
      () => probed.capture(
        VideoCaptureRequest(
          date: _date,
          video: const CaptureBytes(bytes: <int>[9, 0, 5], mime: 'video/mp4'),
          durationMs: 9050,
        ),
      ),
    );

    expect(result!.entry.durationMs, 8990);
    final MediaBlob? blob = await tester.runAsync<MediaBlob?>(
      () => media.blobById(result.entry.mediaId!),
    );
    expect(
      platform.openedUris.map((String? uri) => Uri.parse(uri!).toFilePath()),
      <String>[media.absolutePath(blob!)],
    );
    expect(platform.disposedPlayers, <int>[_playerId]);
  });

  test("a failed or empty measurement keeps the recorder's duration",
      () async {
    final List<Future<Duration?> Function()> failures =
        <Future<Duration?> Function()>[
      () async => throw StateError('the player could not open the file'),
      () async => Duration.zero,
      () async => null,
    ];

    for (final Future<Duration?> Function() failure in failures) {
      final JournalCaptureService probed = JournalCaptureService(
        journal: journal,
        media: media,
        durationProbe: _FakeDurationProbe(failure),
      );

      final CaptureResult result = await probed.capture(
        VideoCaptureRequest(
          date: _date,
          video: const CaptureBytes(bytes: <int>[9, 0, 5], mime: 'video/mp4'),
          durationMs: 9050,
        ),
      );

      expect(result.entry.durationMs, 9050);
    }
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
