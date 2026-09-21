import 'dart:async';
import 'dart:io';

import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/day_detail/day_detail_panel.dart';
import 'package:field_notes/features/day_detail/day_detail_providers.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart';
import 'package:field_notes/features/notes/notes.dart';
import 'package:field_notes/features/today/today_entry_feed.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../entry_cards/support/fake_video_player.dart';
import '../notes/support/notes_harness.dart'
    show FakeNoteMediaResolver, availablePhoto, photoIdA, photoLine, prefixOf;
import 'support/today_harness.dart';

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

Widget _feed(String date) {
  return CustomScrollView(
    slivers: <Widget>[TodayEntryFeed(date: date)],
  );
}

List<Override> _overrides({
  required Stream<List<Entry>> entries,
  List<EntryPhoto> photos = const <EntryPhoto>[],
  MediaResolver resolver = const StubMediaResolver(),
}) {
  return <Override>[
    entriesForDateProvider.overrideWith((Ref ref, String date) => entries),
    photosForEntryProvider.overrideWith(
      (Ref ref, String entryId) => Stream<List<EntryPhoto>>.value(photos),
    ),
    todayMediaResolverProvider.overrideWith((Ref ref) async => resolver),
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
  testWidgets('renders one card per entry and no photo strip',
      (WidgetTester tester) async {
    await pumpToday(
      tester,
      _feed('2026-07-19'),
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
    expect(find.byType(MediaImage), findsNothing);
  });

  testWidgets('a note photo line renders as a block image on the Today card',
      (WidgetTester tester) async {
    await pumpToday(
      tester,
      _feed('2026-07-19'),
      overrides: _overrides(
        entries: Stream<List<Entry>>.value(<Entry>[
          todayTestEntry(
            id: 'entry-1',
            textContent:
                'morning walk\n${photoLine(photoIdA, size: PhotoSize.small)}',
          ),
        ]),
        resolver: FakeNoteMediaResolver(<String, ResolvedMedia>{
          prefixOf(photoIdA): availablePhoto(photoIdA),
        }),
      ),
    );

    final Finder document = find.byType(NoteDocument);
    expect(find.byType(StackedPhoto), findsOneWidget);
    expect(find.byType(MediaImage), findsOneWidget);
    expect(
      tester.getSize(find.byKey(notePhotoFrameKey)).width,
      closeTo(0.55 * tester.getSize(document).width, 0.01),
    );
    expect(find.text('morning walk'), findsOneWidget);
  });

  testWidgets('clamps and centres the feed card on a desktop pane',
      (WidgetTester tester) async {
    await pumpToday(
      tester,
      _feed('2026-07-19'),
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
      _feed('2026-07-19'),
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
      _feed('2026-07-19'),
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
      _feed('2026-07-19'),
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
      _feed('2026-07-19'),
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
      _feed('2026-07-19'),
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
      _feed('2026-07-19'),
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

  testWidgets('builds only the entries near the viewport for a long day',
      (WidgetTester tester) async {
    const int entryCount = 50;
    await pumpToday(
      tester,
      _feed('2026-07-19'),
      overrides: _overrides(
        entries: Stream<List<Entry>>.value(<Entry>[
          for (int i = 0; i < entryCount; i++)
            todayTestEntry(id: 'entry-$i', textContent: 'log number $i'),
        ]),
      ),
    );

    final int built = find.byType(EntryCard).evaluate().length;
    expect(built, greaterThan(0));
    expect(built, lessThan(entryCount));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a feed card opens day detail focused on the tapped entry',
      (WidgetTester tester) async {
    await pumpToday(
      tester,
      _feed('2026-07-19'),
      overrides: <Override>[
        ..._overrides(
          entries: Stream<List<Entry>>.value(<Entry>[
            todayTestEntry(id: 'entry-1', textContent: 'morning walk'),
            todayTestEntry(id: 'entry-2', textContent: 'coffee on the porch'),
          ]),
        ),
        dayDetailMediaResolverProvider
            .overrideWith((Ref ref) async => const StubMediaResolver()),
        dayForDateProvider.overrideWith(
          (Ref ref, String date) => Stream<Day?>.value(
            todayTestDay(date: date, mood: Mood.calm),
          ),
        ),
      ],
    );

    await tester.tapAt(tester.getCenter(find.text('coffee on the porch')));
    await tester.pumpAndSettle();

    final DayDetailPanel panel =
        tester.widget<DayDetailPanel>(find.byType(DayDetailPanel));
    expect(panel.date, '2026-07-19');
    expect(panel.focusEntryId, 'entry-2');
  });
}
