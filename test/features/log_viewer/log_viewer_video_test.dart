import 'dart:async';
import 'dart:io';

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart';
import 'package:field_notes/features/log_viewer/log_viewer.dart';
import 'package:field_notes/features/log_viewer/log_viewer_panel.dart';
import 'package:field_notes/features/notes/notes.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../entry_cards/support/fake_video_player.dart';

const String _date = '2026-07-19';

class _AvailableVideoResolver implements MediaResolver {
  const _AvailableVideoResolver(this.file);

  final File file;

  @override
  ResolvedMedia? resolved(String? mediaId) => null;

  @override
  Future<ResolvedMedia> resolve(String? mediaId) async {
    if (mediaId != 'vid') {
      return const ResolvedMedia.missing();
    }
    return ResolvedMedia.available(
      blob: MediaBlob(
        id: 'vid',
        relPath: 'v.mp4',
        mime: 'video/mp4',
        kind: MediaKind.video,
        bytes: 4,
        createdAt: 0,
      ),
      file: file,
    );
  }
}

File _writtenVideoFile() {
  final Directory dir = Directory.systemTemp.createTempSync('viewer_video');
  addTearDown(() {
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });
  final File file = File('${dir.path}/v.mp4');
  file.writeAsBytesSync(<int>[0, 1, 2, 3]);
  return file;
}

Entry _videoEntry() {
  return Entry(
    id: 'entry-1',
    dayId: 'day-1',
    type: EntryType.video,
    mediaId: 'vid',
    durationMs: 4000,
    createdAt: DateTime(2026, 7, 19, 21, 4).millisecondsSinceEpoch,
    updatedAt: 0,
  );
}

class _Opener extends StatelessWidget {
  const _Opener();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showLogViewer(
          context,
          date: _date,
          entryId: 'entry-1',
          exit: LogViewerExit.close,
        ),
        child: const Text('open log'),
      ),
    );
  }
}

Future<void> _openViewer(
  WidgetTester tester, {
  required Future<MediaResolver> resolver,
  required VideoSlots slots,
  required EntryVideoPlayerFactory buildPlayer,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        entriesForDateProvider.overrideWith(
          (Ref ref, String date) =>
              Stream<List<Entry>>.value(<Entry>[_videoEntry()]),
        ),
        notesMediaResolverProvider.overrideWith((Ref ref) => resolver),
        videoSlotsProvider.overrideWithValue(slots),
        todayVideoPlayerFactoryProvider.overrideWithValue(buildPlayer),
        todayClockProvider.overrideWithValue(() => DateTime(2026, 7, 19, 22)),
      ],
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: _Opener(),
      ),
    ),
  );
  await tester.tap(find.text('open log'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('hands every video card the shared decoder slot registry',
      (WidgetTester tester) async {
    final LruVideoSlots slots = LruVideoSlots(cap: 1);
    addTearDown(slots.dispose);
    final VideoSlotToken? occupant = slots.acquire(
      onEvicted: () {},
      evictionRights: VideoSlotEvictionRights.evictUnpinned,
    );
    slots.pin(occupant);

    final File file = _writtenVideoFile();
    final Completer<MediaResolver> pending = Completer<MediaResolver>();

    int playersBuilt = 0;
    await _openViewer(
      tester,
      resolver: pending.future,
      slots: slots,
      buildPlayer: () {
        playersBuilt++;
        return FakeEntryVideoPlayer();
      },
    );

    pending.complete(_AvailableVideoResolver(file));
    await tester.pumpAndSettle();

    expect(find.byKey(logViewerPanelKey), findsOneWidget);
    expect(find.byType(VideoBody), findsOneWidget);
    expect(tester.widget<VideoBody>(find.byType(VideoBody)).slots, same(slots));
    expect(find.byType(CorruptMediaPlaceholder), findsNothing);
    expect(find.byType(NeutralMediaPlaceholder), findsOneWidget);
    expect(playersBuilt, 0);
  });

  testWidgets('loads a video card mounted before the media resolver settles',
      (WidgetTester tester) async {
    final LruVideoSlots slots = LruVideoSlots(cap: 1);
    addTearDown(slots.dispose);

    final File file = _writtenVideoFile();
    final Completer<MediaResolver> pending = Completer<MediaResolver>();
    final List<FakeEntryVideoPlayer> built = <FakeEntryVideoPlayer>[];

    await _openViewer(
      tester,
      resolver: pending.future,
      slots: slots,
      buildPlayer: () {
        final FakeEntryVideoPlayer player = FakeEntryVideoPlayer();
        built.add(player);
        return player;
      },
    );

    expect(find.byKey(logViewerPanelKey), findsOneWidget);
    expect(find.byType(CorruptMediaPlaceholder), findsNothing);
    expect(find.byType(VideoBody), findsNothing);
    expect(built, isEmpty);

    final MediaResolver settled = _AvailableVideoResolver(file);
    pending.complete(settled);
    await tester.pumpAndSettle();

    final VideoBody body = tester.widget<VideoBody>(find.byType(VideoBody));
    expect(body.resolver, same(settled));
    expect(body.entry.mediaId, 'vid');
    expect(body.slots, same(slots));
    expect(find.byType(CorruptMediaPlaceholder), findsNothing);
    expect(built, hasLength(1));
    expect(built.single.loadCalls, <String>[file.path]);
    expect(
      find.byKey(const ValueKey<String>('fake-video-surface')),
      findsOneWidget,
    );
  });
}
