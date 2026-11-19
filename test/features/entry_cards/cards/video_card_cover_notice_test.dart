import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/entry_cards/compact/compact_log_card.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart'
    show ResolvedMedia;
import 'package:field_notes/features/entry_cards/media/media_placeholders.dart'
    show CorruptMediaPlaceholder;
import 'package:field_notes/features/entry_cards/playback/video_slots.dart';
import 'package:field_notes/features/entry_cards/playback/video_slots_provider.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/state.dart';

import '../../day_detail/support/day_detail_harness.dart'
    show FakeJournalRepository;
import '../support/entry_cards_harness.dart' show FakeMediaResolver;
import '../support/fake_video_player.dart';
import '../support/video_card_harness.dart'
    show posterFixtureFile, videoFixtureFile, videoResolverFor;

Entry _video() {
  final int at = DateTime(2026, 7, 19, 9, 12).millisecondsSinceEpoch;
  return Entry(
    id: 'video-1',
    dayId: 'day-1',
    type: EntryType.video,
    mediaId: 'vid',
    thumbnailMediaId: 'thumb',
    durationMs: 64000,
    createdAt: at,
    updatedAt: at,
  );
}

FakeMediaResolver _resolver({required bool videoOnDisk}) {
  final FakeMediaResolver resolver = videoResolverFor(
    videoFixtureFile(),
    poster: posterFixtureFile(),
  )..memoize('thumb');
  if (!videoOnDisk) {
    resolver.set('vid', const ResolvedMedia.missing());
  }
  return resolver..memoize('vid');
}

Future<void> _pumpCard(WidgetTester tester, {required bool videoOnDisk}) async {
  tester.view.physicalSize = const Size(1200, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final VideoSlots slots = LruVideoSlots(cap: 2);
  addTearDown(slots.dispose);
  final Entry entry = _video();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        journalRepositoryProvider.overrideWithValue(
          FakeJournalRepository(entries: <Entry>[entry]),
        ),
        todayVideoPlayerFactoryProvider.overrideWithValue(
          FakeEntryVideoPlayer.new,
        ),
        videoSlotsProvider.overrideWithValue(slots),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: <Widget>[
              CompactLogCard(
                entry: entry,
                resolver: _resolver(videoOnDisk: videoOnDisk),
                density: CompactLogDensity.feed,
                onOpen: () {},
                onDelete: () {},
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  for (int frame = 0; frame < 4; frame += 1) {
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets(
    'a Today card video that cannot play shows its notice and Retry after play',
    (WidgetTester tester) async {
      await _pumpCard(tester, videoOnDisk: false);

      await tester.tap(find.byKey(compactLogVideoPlayKey));
      await _settle(tester);
      await tester.pump(const Duration(seconds: 60));

      expect(find.byType(CorruptMediaPlaceholder), findsOneWidget);
      expect(find.byKey(compactLogPosterKey), findsNothing);
      expect(find.text("Can't play this video").hitTestable(), findsOneWidget);
    },
  );
}
