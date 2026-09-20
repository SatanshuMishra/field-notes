import 'dart:async';
import 'dart:io';

import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart';
import 'package:field_notes/features/today/today_entry_feed.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../entry_cards/support/fake_video_player.dart';
import 'support/today_harness.dart';

class _AvailableVideoResolver implements MediaResolver {
  const _AvailableVideoResolver(this.file);

  final File file;

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
  final Directory dir = Directory.systemTemp.createTempSync('today_video');
  addTearDown(() {
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });
  final File file = File('${dir.path}/v.mp4');
  file.writeAsBytesSync(<int>[0, 1, 2, 3]);
  return file;
}

List<Override> _overrides({
  required Stream<List<Entry>> entries,
  List<EntryPhoto> photos = const <EntryPhoto>[],
}) {
  return <Override>[
    entriesForDateProvider.overrideWith((Ref ref, String date) => entries),
    photosForEntryProvider.overrideWith(
      (Ref ref, String entryId) => Stream<List<EntryPhoto>>.value(photos),
    ),
    todayMediaResolverProvider
        .overrideWith((Ref ref) async => const StubMediaResolver()),
  ];
}

List<Override> _videoEntryOverrides({
  required Future<MediaResolver> resolver,
  required EntryVideoPlayer Function() buildPlayer,
  required VideoSlots slots,
}) {
  return <Override>[
    entriesForDateProvider.overrideWith(
      (Ref ref, String date) => Stream<List<Entry>>.value(<Entry>[
        todayTestEntry(
          id: 'entry-1',
          type: EntryType.video,
          textContent: null,
          mediaId: 'vid',
          durationMs: 4000,
        ),
      ]),
    ),
    photosForEntryProvider.overrideWith(
      (Ref ref, String entryId) =>
          Stream<List<EntryPhoto>>.value(const <EntryPhoto>[]),
    ),
    todayMediaResolverProvider.overrideWith((Ref ref) => resolver),
    todayVideoPlayerFactoryProvider.overrideWithValue(buildPlayer),
    videoSlotsProvider.overrideWithValue(slots),
  ];
}

void main() {
  testWidgets('renders one card per entry with its photos',
      (WidgetTester tester) async {
    await pumpToday(
      tester,
      const TodayEntryFeed(date: '2026-07-19'),
      overrides: _overrides(
        entries: Stream<List<Entry>>.value(<Entry>[
          todayTestEntry(id: 'entry-1', textContent: 'morning walk'),
          todayTestEntry(id: 'entry-2', textContent: 'coffee on the porch'),
        ]),
        photos: <EntryPhoto>[todayTestPhoto()],
      ),
    );

    expect(find.byType(EntryCard), findsNWidgets(2));
    expect(find.text('morning walk'), findsOneWidget);
    expect(find.text('coffee on the porch'), findsOneWidget);
    expect(find.byType(InlinePhotoStrip), findsNWidgets(2));
  });

  testWidgets('clamps and centres the feed card on a desktop pane',
      (WidgetTester tester) async {
    await pumpToday(
      tester,
      const TodayEntryFeed(date: '2026-07-19'),
      surface: todayDesktopSurface,
      overrides: _overrides(
        entries: Stream<List<Entry>>.value(<Entry>[
          todayTestEntry(id: 'entry-1', textContent: 'morning walk'),
        ]),
      ),
    );

    expect(find.byType(NoteColumn), findsNWidgets(2));
    expect(tester.getSize(find.byType(EntryCard)).width, 590);
    expect(tester.getCenter(find.byType(EntryCard)).dx, closeTo(500, 0.01));
    expect(tester.getSize(find.text('morning walk')).width, 560);
  });

  testWidgets('lets the feed card fill a phone pane edge to edge',
      (WidgetTester tester) async {
    await pumpToday(
      tester,
      const TodayEntryFeed(date: '2026-07-19'),
      surface: todayPhoneSurface,
      overrides: _overrides(
        entries: Stream<List<Entry>>.value(<Entry>[
          todayTestEntry(id: 'entry-1', textContent: 'morning walk'),
        ]),
      ),
    );

    expect(tester.getSize(find.byType(EntryCard)).width, 420);
    expect(tester.getSize(find.text('morning walk')).width, 390);
  });

  testWidgets('renders an empty state when today has no entries',
      (WidgetTester tester) async {
    await pumpToday(
      tester,
      const TodayEntryFeed(date: '2026-07-19'),
      overrides: _overrides(entries: Stream<List<Entry>>.value(const <Entry>[])),
    );

    expect(find.text(todayFeedEmptyHeadline), findsOneWidget);
    expect(find.text(todayFeedEmptyMessage), findsOneWidget);
    expect(find.byType(EntryCard), findsNothing);
  });

  testWidgets('renders loaded entries before the media resolver settles',
      (WidgetTester tester) async {
    final Completer<MediaResolver> pending = Completer<MediaResolver>();
    await pumpToday(
      tester,
      const TodayEntryFeed(date: '2026-07-19'),
      overrides: <Override>[
        entriesForDateProvider.overrideWith(
          (Ref ref, String date) => Stream<List<Entry>>.value(<Entry>[
            todayTestEntry(id: 'entry-1', textContent: 'morning walk'),
          ]),
        ),
        photosForEntryProvider.overrideWith(
          (Ref ref, String entryId) =>
              Stream<List<EntryPhoto>>.value(const <EntryPhoto>[]),
        ),
        todayMediaResolverProvider.overrideWith((Ref ref) => pending.future),
      ],
    );

    expect(find.byType(EntryCard), findsOneWidget);
    expect(find.text('morning walk'), findsOneWidget);

    pending.complete(const StubMediaResolver());
    await tester.pumpAndSettle();

    expect(find.byType(EntryCard), findsOneWidget);
  });

  testWidgets('surfaces a friendly error when the entry stream fails',
      (WidgetTester tester) async {
    await pumpToday(
      tester,
      const TodayEntryFeed(date: '2026-07-19'),
      overrides: _overrides(
        entries: Stream<List<Entry>>.error(Exception('db unavailable')),
      ),
    );

    expect(find.text("Couldn't load today's entries."), findsOneWidget);
    expect(find.byType(EntryCard), findsNothing);
  });

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
    await pumpToday(
      tester,
      const TodayEntryFeed(date: '2026-07-19'),
      overrides: _videoEntryOverrides(
        resolver: pending.future,
        buildPlayer: () {
          playersBuilt++;
          return FakeEntryVideoPlayer();
        },
        slots: slots,
      ),
    );

    pending.complete(_AvailableVideoResolver(file));
    await tester.pumpAndSettle();

    expect(find.byType(VideoBody), findsOneWidget);
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

    await pumpToday(
      tester,
      const TodayEntryFeed(date: '2026-07-19'),
      overrides: _videoEntryOverrides(
        resolver: pending.future,
        buildPlayer: () {
          final FakeEntryVideoPlayer player = FakeEntryVideoPlayer();
          built.add(player);
          return player;
        },
        slots: slots,
      ),
    );

    expect(find.byType(VideoBody), findsOneWidget);
    expect(find.byType(CorruptMediaPlaceholder), findsNothing);
    expect(find.byType(NeutralMediaPlaceholder), findsOneWidget);
    expect(built, isEmpty);

    pending.complete(_AvailableVideoResolver(file));
    await tester.pumpAndSettle();

    expect(find.byType(CorruptMediaPlaceholder), findsNothing);
    expect(built, hasLength(1));
    expect(built.single.loadCalls, <String>[file.path]);
    expect(
      find.byKey(const ValueKey<String>('fake-video-surface')),
      findsOneWidget,
    );
  });
}
