import 'dart:async';

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/day_detail/day_detail_panel.dart';
import 'package:field_notes/features/day_detail/day_detail_providers.dart';
import 'package:field_notes/features/entry_cards/compact/compact_log_card.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart';
import 'package:field_notes/features/log_viewer/log_viewer.dart';
import 'package:field_notes/features/log_viewer/log_viewer_panel.dart';
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

    expect(find.byType(CompactLogCard), findsNWidgets(2));
    expect(find.text('morning walk'), findsOneWidget);
    expect(find.text('coffee on the porch'), findsOneWidget);
    expect(find.byType(MediaImage), findsNothing);
  });

  testWidgets('a note photo line renders as a compact thumbnail on the Today card',
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

    expect(find.byType(StackedPhoto), findsNothing);
    expect(find.byType(MediaImage), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(compactLogThumbnailKey),
        matching: find.byType(MediaImage),
      ),
      findsOneWidget,
    );
    expect(tester.getSize(find.byKey(compactLogThumbnailKey)), const Size(64, 64));
    expect(find.text('morning walk'), findsOneWidget);
    expect(find.text('1 photo'), findsOneWidget);
  });

  testWidgets('the feed card and its note fill a desktop pane',
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

    expect(tester.getSize(find.byType(CompactLogCard)).width, 1000);
    expect(tester.getSize(find.text('morning walk')).width, 970);
  });

  testWidgets('a video card fills a desktop pane',
      (WidgetTester tester) async {
    final LruVideoSlots slots = LruVideoSlots(cap: 1);
    addTearDown(slots.dispose);

    await pumpToday(
      tester,
      _feed('2026-07-19'),
      surface: todayDesktopSurface,
      overrides: _videoEntryOverrides(
        resolver: Future<MediaResolver>.value(const StubMediaResolver()),
        buildPlayer: FakeEntryVideoPlayer.new,
        slots: slots,
      ),
    );
    await tester.pump();

    expect(find.byType(VideoBody), findsNothing);
    expect(
      tester.getSize(find.byKey(compactLogThumbnailKey)),
      const Size(104, 64),
    );
    expect(find.text('Watch ›'), findsOneWidget);
    expect(tester.getSize(find.byType(CompactLogCard)).width, 1000);
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

    expect(tester.getSize(find.byType(CompactLogCard)).width, 420);
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
    expect(find.byType(CompactLogCard), findsNothing);
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

    expect(find.byType(CompactLogCard), findsOneWidget);
    expect(find.text('morning walk'), findsOneWidget);

    pending.complete(const StubMediaResolver());
    await tester.pumpAndSettle();

    expect(find.byType(CompactLogCard), findsOneWidget);
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
    expect(find.byType(CompactLogCard), findsNothing);
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

    final int built = find.byType(CompactLogCard).evaluate().length;
    expect(built, greaterThan(0));
    expect(built, lessThan(entryCount));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a feed card opens view mode on the tapped entry',
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
        notesMediaResolverProvider
            .overrideWith((Ref ref) async => const StubMediaResolver()),
        dayDetailMediaResolverProvider
            .overrideWith((Ref ref) async => const StubMediaResolver()),
        dayForDateProvider.overrideWith(
          (Ref ref, String date) => Stream<Day?>.value(
            todayTestDay(date: date, mood: Mood.calm),
          ),
        ),
        todayClockProvider.overrideWithValue(() => DateTime(2026, 7, 19, 20)),
      ],
    );

    final Finder secondCard = find.byType(CompactLogCard).at(1);
    await tester.tapAt(tester.getTopLeft(secondCard) + const Offset(24, 18));
    await tester.pumpAndSettle();

    final LogViewerPanel panel =
        tester.widget<LogViewerPanel>(find.byType(LogViewerPanel));
    expect(panel.date, '2026-07-19');
    expect(panel.entryId, 'entry-2');
    expect(panel.exit, LogViewerExit.close);
    expect(find.byType(DayDetailPanel), findsNothing);
  });
}
