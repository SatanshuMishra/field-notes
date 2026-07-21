import 'dart:async';

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart';
import 'package:field_notes/features/today/today_entry_feed.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/today_harness.dart';

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

  testWidgets('renders an empty state when today has no entries',
      (WidgetTester tester) async {
    await pumpToday(
      tester,
      const TodayEntryFeed(date: '2026-07-19'),
      overrides: _overrides(entries: Stream<List<Entry>>.value(const <Entry>[])),
    );

    expect(find.text('Nothing captured yet today.'), findsOneWidget);
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
}
