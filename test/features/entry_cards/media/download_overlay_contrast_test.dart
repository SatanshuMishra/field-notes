import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/data/database/app_database.dart' as db;
import 'package:field_notes/data/media/blob_paths.dart';
import 'package:field_notes/data/media/content_hash.dart';
import 'package:field_notes/data/media/filesystem_media_store.dart';
import 'package:field_notes/data/sync/change_recorder.dart';
import 'package:field_notes/data/sync/media/download_service.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart';
import 'package:field_notes/features/entry_cards/media/syncing_media_resolver.dart';
import 'package:field_notes/features/log_viewer/log_viewer.dart';
import 'package:field_notes/features/notes/notes_providers.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../support/fake_video_player.dart';

const String _date = '2026-07-19';

const double _minimumContrast = 4.5;
const double _groundOffset = 3;

double _linear(double channel) => channel <= 0.03928
    ? channel / 12.92
    : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color color) =>
    0.2126 * _linear(color.r) +
    0.7152 * _linear(color.g) +
    0.0722 * _linear(color.b);

double _contrast(Color text, Color ground) {
  final double first = _luminance(Color.alphaBlend(text, ground));
  final double second = _luminance(ground);
  return (math.max(first, second) + 0.05) / (math.min(first, second) + 0.05);
}

Future<List<Color>> _groundAround(WidgetTester tester, Finder text) async {
  final Rect rect = tester.getRect(text);
  final double ratio = tester.view.devicePixelRatio;
  final ui.Image image = await captureImage(tester.binding.rootElement!);
  late ByteData bytes;
  await tester.runAsync(() async {
    bytes = (await image.toByteData())!;
  });
  final int width = image.width;
  image.dispose();
  Color pixelAt(Offset point) {
    final int x = (point.dx * ratio).round();
    final int y = (point.dy * ratio).round();
    final int index = (y * width + x) * 4;
    return Color.fromARGB(
      255,
      bytes.getUint8(index),
      bytes.getUint8(index + 1),
      bytes.getUint8(index + 2),
    );
  }

  return <Color>[
    pixelAt(Offset(rect.left - _groundOffset, rect.center.dy)),
    pixelAt(Offset(rect.right + _groundOffset, rect.center.dy)),
    pixelAt(Offset(rect.center.dx, rect.top - _groundOffset)),
    pixelAt(Offset(rect.center.dx, rect.bottom + _groundOffset)),
  ];
}

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
        'fn_download_contrast',
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

  SyncingMediaResolver resolver({DownloadProgressLookup? progressOf}) =>
      SyncingMediaResolver(
        inner: MediaStoreResolver(store),
        store: store,
        fetch: (String _) async => false,
        posterOf: (String _) async => null,
        recordOpen: (String _) async {},
        progressOf: progressOf ?? (String _) => null,
      );
}

Entry _entry({
  required String id,
  required EntryType type,
  String? mediaId,
  String? thumbnailMediaId,
  int? durationMs,
}) {
  return Entry(
    id: id,
    dayId: 'day-1',
    type: type,
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
  required TargetPlatform platform,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        entriesForDateProvider.overrideWith(
          (Ref ref, String date) => Stream<List<Entry>>.value(<Entry>[entry]),
        ),
        notesMediaResolverProvider.overrideWith((Ref ref) async => resolver),
        videoSlotsProvider.overrideWithValue(const UnlimitedVideoSlots()),
        todayVideoPlayerFactoryProvider.overrideWithValue(() => player),
        todayClockProvider.overrideWithValue(() => DateTime(2026, 7, 19, 22)),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: platform),
        home: _ViewerOpener(entryId: entry.id),
      ),
    ),
  );
  await tester.tap(find.text('open log'));
  await _settle(tester);
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  for (final (String frame, img.Color fill) in <(String, img.Color)>[
    ('pure black', img.ColorRgb8(0, 0, 0)),
    ('pure white', img.ColorRgb8(255, 255, 255)),
  ]) {
    testWidgets(
      'the downloading viewer text reads over a $frame poster',
      (WidgetTester tester) async {
        final TargetPlatform platform = defaultTargetPlatform;
        final _Journal journal = await _Journal.open(tester);
        final List<int> poster = img.encodePng(
          img.fill(img.Image(width: 8, height: 6), color: fill),
        );
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
              (MediaDownloadProgress update) =>
                  update.blobId.startsWith(mediaId),
            ),
          ),
          player: player,
          platform: platform,
        );

        progress.add(
          MediaDownloadProgress(
            blobId: videoId,
            received: 3 * megabyte,
            total: 12 * megabyte,
          ),
        );
        await _settle(tester);

        final Finder caption = find.textContaining('downloading');
        expect(caption, findsOneWidget);
        final Color ink = tester
            .renderObject<RenderParagraph>(caption)
            .text
            .style!
            .color!;
        final List<Color> grounds = await _groundAround(tester, caption);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 2));
        for (final Color ground in grounds) {
          expect(
            _contrast(ink, ground),
            greaterThanOrEqualTo(_minimumContrast),
          );
        }
      },
      variant: TargetPlatformVariant(<TargetPlatform>{
        TargetPlatform.android,
        TargetPlatform.macOS,
        TargetPlatform.windows,
      }),
    );
  }
}
