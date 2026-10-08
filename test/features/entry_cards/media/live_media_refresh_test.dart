import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:field_notes/data/database/app_database.dart' as db;
import 'package:field_notes/data/media/blob_paths.dart';
import 'package:field_notes/data/media/content_hash.dart';
import 'package:field_notes/data/media/filesystem_media_store.dart';
import 'package:field_notes/data/sync/change_recorder.dart';
import 'package:field_notes/data/sync/media/download_service.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/day_detail/day_detail_panel.dart';
import 'package:field_notes/features/day_detail/day_detail_providers.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart';
import 'package:field_notes/features/entry_cards/media/syncing_media_resolver.dart';
import 'package:field_notes/features/log_viewer/log_viewer.dart';
import 'package:field_notes/features/log_viewer/video_viewer_view.dart';
import 'package:field_notes/features/notes/notes_providers.dart';
import 'package:field_notes/features/today/today_entry_feed.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../../capture/core/capture_test_support.dart' show FakeDraftStore;
import '../../day_detail/support/day_detail_harness.dart';
import '../support/fake_audio_player.dart';
import '../support/fake_video_player.dart';
import '../../notes/support/notes_harness.dart' show photoLine;
import '../../today/support/today_harness.dart';

const String _date = '2026-07-19';
const String _voiceUnavailable = "Can't play this recording";
const String _videoUnavailable = "Can't play this video";
const Duration _viewerEntrance = Duration(milliseconds: 400);

Future<void> _settle(WidgetTester tester) async {
  for (int round = 0; round < 8; round++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump();
  }
}

List<int> _bytes(int length, int seed) =>
    List<int>.generate(length, (int index) => (index * 19 + seed) % 251);

final class _Journal {
  _Journal._(this.database, this.root, this.store);

  static Future<_Journal> open(WidgetTester tester) async {
    late _Journal journal;
    await tester.runAsync(() async {
      final db.AppDatabase database = db.AppDatabase(NativeDatabase.memory());
      final Directory root = await Directory.systemTemp.createTemp(
        'fn_live_media',
      );
      journal = _Journal._(
        database,
        root,
        FilesystemMediaStore(
          database: database,
          recorder: ChangeRecorder(database),
          root: root,
        ),
      );
    });
    addTearDown(
      () => tester.runAsync(() async {
        await journal.database.close();
        await journal.root.delete(recursive: true);
      }),
    );
    return journal;
  }

  final db.AppDatabase database;
  final Directory root;
  final FilesystemMediaStore store;

  Future<String> arrivedMetadata(
    WidgetTester tester,
    List<int> bytes, {
    required String mime,
    required MediaKind kind,
    int? width,
    int? height,
  }) async {
    final String id = sha256Hex(bytes);
    await tester.runAsync(
      () => database
          .into(database.mediaBlobs)
          .insert(
            db.MediaBlobsCompanion.insert(
              id: id,
              relPath: relPathForBlob(id: id, mime: mime, kind: kind),
              mime: mime,
              kind: kind.id,
              bytes: bytes.length,
              width: Value(width),
              height: Value(height),
              createdAt: 0,
            ),
          ),
    );
    return id;
  }

  Future<String> storeFile(
    WidgetTester tester,
    List<int> bytes, {
    required String mime,
    required MediaKind kind,
  }) async {
    late String id;
    await tester.runAsync(() async {
      id = (await store.putBytes(bytes: bytes, mime: mime, kind: kind)).id;
    });
    return id;
  }

  SyncingMediaResolver resolver({
    MediaFetcher? fetch,
    DownloadProgressLookup? progressOf,
  }) => SyncingMediaResolver(
    inner: MediaStoreResolver(store),
    store: store,
    fetch: fetch ?? (String _) async => false,
    posterOf: (String _) async => null,
    recordOpen: (String _) async {},
    progressOf: progressOf ?? (String _) => null,
  );
}

Entry _entry({
  required String id,
  required EntryType type,
  String? text,
  String? mediaId,
  String? thumbnailMediaId,
  int? durationMs,
}) {
  return Entry(
    id: id,
    dayId: 'day-1',
    type: type,
    textContent: text,
    mediaId: mediaId,
    thumbnailMediaId: thumbnailMediaId,
    durationMs: durationMs,
    createdAt: DateTime(2026, 7, 19, 21, 4).millisecondsSinceEpoch,
    updatedAt: 0,
  );
}

class _ViewerOpener extends StatelessWidget {
  const _ViewerOpener({required this.entryId});

  final String entryId;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showLogViewer(
          context,
          date: _date,
          entryId: entryId,
          exit: LogViewerExit.close,
        ),
        child: const Text('open log'),
      ),
    );
  }
}

Future<void> _openViewer(
  WidgetTester tester, {
  required Entry entry,
  required MediaResolver resolver,
  required FakeEntryVideoPlayer player,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        entriesForDateProvider.overrideWith(
          (Ref ref, String date) => Stream<List<Entry>>.value(<Entry>[entry]),
        ),
        dayForDateProvider.overrideWith(
          (Ref ref, String date) => Stream<Day?>.value(null),
        ),
        notesMediaResolverProvider.overrideWith((Ref ref) async => resolver),
        videoSlotsProvider.overrideWithValue(const UnlimitedVideoSlots()),
        videoAspectProvider.overrideWith((Ref ref, String mediaId) => null),
        todayVideoPlayerFactoryProvider.overrideWithValue(() => player),
        todayClockProvider.overrideWithValue(() => DateTime(2026, 7, 19, 22)),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: _ViewerOpener(entryId: entry.id),
      ),
    ),
  );
  await tester.tap(find.text('open log'));
  await tester.pump();
  await tester.pump(_viewerEntrance);
  await _settle(tester);
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('an open pop-up shows a photo once its file arrives', (
    WidgetTester tester,
  ) async {
    final _Journal journal = await _Journal.open(tester);
    final List<int> png = img.encodePng(img.Image(width: 6, height: 4));
    final String photoId = await journal.arrivedMetadata(
      tester,
      png,
      mime: 'image/png',
      kind: MediaKind.photo,
      width: 6,
      height: 4,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          journalRepositoryProvider.overrideWithValue(
            FakeJournalRepository(
              entries: <Entry>[
                entryOf(
                  type: EntryType.text,
                  textContent: 'a good day\n${photoLine(photoId)}',
                ),
              ],
            ),
          ),
          draftStoreProvider.overrideWith((Ref ref) => FakeDraftStore()),
          dayDetailMediaResolverProvider.overrideWith(
            (Ref ref) => journal.resolver(),
          ),
          todayClockProvider.overrideWithValue(() => DateTime(2026, 7, 23, 9)),
        ],
        child: dayDetailHarness(const DayDetailPanel(date: _date)),
      ),
    );
    await _settle(tester);
    final Finder photo = find.descendant(
      of: find.byKey(compactLogThumbnailKey),
      matching: find.byType(MediaImage),
    );
    expect(find.byKey(dayDetailPanelKey), findsOneWidget);
    expect(find.byKey(compactLogThumbnailKey), findsOneWidget);
    expect(photo, findsNothing);

    await journal.storeFile(
      tester,
      png,
      mime: 'image/png',
      kind: MediaKind.photo,
    );
    await _settle(tester);

    expect(find.byKey(dayDetailPanelKey), findsOneWidget);
    expect(photo, findsOneWidget);
  });

  testWidgets('Today and the entry viewer show media that arrives later', (
    WidgetTester tester,
  ) async {
    final _Journal journal = await _Journal.open(tester);
    final List<int> voiceBytes = _bytes(700, 1);
    final List<int> videoBytes = _bytes(900, 2);
    final String voiceId = await journal.arrivedMetadata(
      tester,
      voiceBytes,
      mime: 'audio/mp4',
      kind: MediaKind.audio,
    );
    final String videoId = await journal.arrivedMetadata(
      tester,
      videoBytes,
      mime: 'video/mp4',
      kind: MediaKind.video,
    );
    final MediaResolver resolver = journal.resolver();
    final FakeEntryAudioPlayer audio = FakeEntryAudioPlayer();
    tester.view.physicalSize = todayPhoneSurface;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          entriesForDateProvider.overrideWith(
            (Ref ref, String date) => Stream<List<Entry>>.value(<Entry>[
              _entry(
                id: 'voice-1',
                type: EntryType.voice,
                mediaId: voiceId,
                durationMs: 3000,
              ),
            ]),
          ),
          photosForEntryProvider.overrideWith(
            (Ref ref, String entryId) =>
                Stream<List<EntryPhoto>>.value(const <EntryPhoto>[]),
          ),
          todayMediaResolverProvider.overrideWith((Ref ref) async => resolver),
          todayAudioPlayerFactoryProvider.overrideWithValue(() => audio),
        ],
        child: todayHarness(
          const CustomScrollView(
            slivers: <Widget>[TodayEntryFeed(date: _date)],
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(find.text(_voiceUnavailable), findsOneWidget);
    expect(audio.loadCalls, isEmpty);

    await journal.storeFile(
      tester,
      voiceBytes,
      mime: 'audio/mp4',
      kind: MediaKind.audio,
    );
    await _settle(tester);

    expect(find.text(_voiceUnavailable), findsNothing);
    expect(audio.loadCalls, hasLength(1));
    expect(audio.loadCalls.single, endsWith('.m4a'));

    await tester.pumpWidget(const SizedBox.shrink());
    await _settle(tester);
    final FakeEntryVideoPlayer video = FakeEntryVideoPlayer();
    await _openViewer(
      tester,
      entry: _entry(
        id: 'video-1',
        type: EntryType.video,
        mediaId: videoId,
        durationMs: 4000,
      ),
      resolver: resolver,
      player: video,
    );
    expect(find.text(_videoUnavailable), findsOneWidget);
    expect(video.loadCalls, isEmpty);

    await journal.storeFile(
      tester,
      videoBytes,
      mime: 'video/mp4',
      kind: MediaKind.video,
    );
    await _settle(tester);

    expect(find.text(_videoUnavailable), findsNothing);
    expect(video.loadCalls, hasLength(1));
    expect(video.loadCalls.single, endsWith('.mp4'));
  });

  testWidgets('a downloading video shows its progress', (
    WidgetTester tester,
  ) async {
    final _Journal journal = await _Journal.open(tester);
    final List<int> poster = img.encodePng(img.Image(width: 8, height: 6));
    final String posterId = await journal.storeFile(
      tester,
      poster,
      mime: 'image/png',
      kind: MediaKind.photo,
    );
    final String videoId = await journal.arrivedMetadata(
      tester,
      _bytes(1200, 3),
      mime: 'video/mp4',
      kind: MediaKind.video,
    );
    final StreamController<MediaDownloadProgress> progress =
        StreamController<MediaDownloadProgress>.broadcast();
    addTearDown(progress.close);
    final FakeEntryVideoPlayer player = FakeEntryVideoPlayer();
    const int megabyte = 1024 * 1024;

    await _openViewer(
      tester,
      entry: _entry(
        id: 'video-2',
        type: EntryType.video,
        mediaId: videoId,
        thumbnailMediaId: posterId,
        durationMs: 64000,
      ),
      resolver: journal.resolver(
        progressOf: (String mediaId) => progress.stream.where(
          (MediaDownloadProgress update) => update.blobId.startsWith(mediaId),
        ),
      ),
      player: player,
    );
    expect(
      find.text('Video · 1:04 · downloading 0.0 of 12.0 MB'),
      findsNothing,
    );

    progress.add(
      MediaDownloadProgress(
        blobId: videoId,
        received: 3 * megabyte,
        total: 12 * megabyte,
      ),
    );
    await _settle(tester);

    expect(
      find.text('Video · 1:04 · downloading 3.0 of 12.0 MB'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp('downloading 3.0 of 12.0 MB')),
      findsOneWidget,
    );
    expect(find.byType(MediaImage), findsWidgets);
    expect(player.loadCalls, isEmpty);

    progress.add(
      MediaDownloadProgress(
        blobId: videoId,
        received: 9 * megabyte,
        total: 12 * megabyte,
      ),
    );
    await _settle(tester);
    expect(
      find.text('Video · 1:04 · downloading 9.0 of 12.0 MB'),
      findsOneWidget,
    );

    progress.add(
      MediaDownloadProgress(
        blobId: videoId,
        received: 12 * megabyte,
        total: 12 * megabyte,
      ),
    );
    await _settle(tester);
    expect(find.textContaining('downloading'), findsNothing);
  });
}
