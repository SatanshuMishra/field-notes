import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/day_detail/day_detail_panel.dart';
import 'package:field_notes/features/day_detail/day_detail_providers.dart';
import 'package:field_notes/features/mood/mood_banner.dart';
import 'package:field_notes/features/mood/mood_banner_for_date.dart';
import 'package:field_notes/features/sound/sound_providers.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/state.dart';

import '../capture/core/capture_test_support.dart' show FakeDraftStore;
import '../day_detail/support/day_detail_harness.dart' as day_detail;
import '../sound/support/fake_sound_player.dart';
import 'support/mood_harness.dart';

const String _pastDate = '2026-07-02';

List<Override> _overrides({
  required FakeJournalRepository repository,
  required FakeSoundPlayer player,
}) {
  return <Override>[
    journalRepositoryProvider.overrideWithValue(repository),
    appSettingsProvider.overrideWith(
      (Ref ref) => Stream<AppSettings>.value(AppSettings.defaults),
    ),
    soundPlayerProvider.overrideWithValue(player),
    todayClockProvider.overrideWithValue(() => DateTime(2026, 7, 19, 9)),
  ];
}

Future<void> _pumpPastDayCard(WidgetTester tester, Mood mood) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: _overrides(
        repository: FakeJournalRepository(
          initialDay: testDay(date: _pastDate, mood: mood),
        ),
        player: FakeSoundPlayer(),
      ),
      child: moodHarness(const MoodBannerForDate(date: _pastDate)),
    ),
  );
  await tester.pump();
}

Future<void> _openPastDaySheet(WidgetTester tester, Mood mood) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        journalRepositoryProvider.overrideWithValue(
          day_detail.FakeJournalRepository(
            day: testDay(date: _pastDate, mood: mood),
            entries: <Entry>[
              day_detail.entryOf(
                type: EntryType.text,
                textContent: 'a good day',
              ),
            ],
          ),
        ),
        draftStoreProvider.overrideWith((Ref ref) => FakeDraftStore()),
        dayDetailMediaResolverProvider.overrideWith(
          (Ref ref) => day_detail.FakeMediaResolver(),
        ),
        todayClockProvider.overrideWithValue(() => DateTime(2026, 7, 19, 9)),
      ],
      child: day_detail.dayDetailHarness(
        const DayDetailPanel(date: _pastDate),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

List<String> _labelParts(String label) => <String>[
      for (final String line in label.split('\n'))
        for (final String part in line.split(', '))
          if (part.trim().isNotEmpty) part.trim(),
    ];

void main() {
  testWidgets("a past day with a mood reads Felt and the day's bloom",
      (WidgetTester tester) async {
    final FakeJournalRepository fake = FakeJournalRepository(
      initialDay: testDay(date: _pastDate, mood: Mood.calm),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(
          repository: fake,
          player: FakeSoundPlayer(),
        ),
        child: moodHarness(const MoodBannerForDate(date: _pastDate)),
      ),
    );
    await tester.pump();

    expect(find.text('Felt Calm'), findsOneWidget);
    expect(find.text("Lavender · the day's bloom"), findsOneWidget);
    expect(find.text('Feeling Calm today'), findsNothing);
  });

  testWidgets('a past day with a mood offers Change mood through the live flow',
      (WidgetTester tester) async {
    final FakeJournalRepository fake = FakeJournalRepository(
      initialDay: testDay(date: _pastDate, mood: Mood.calm),
    );
    final FakeSoundPlayer player = FakeSoundPlayer();
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(repository: fake, player: player),
        child: moodHarness(const MoodBannerForDate(date: _pastDate)),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Change mood'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Happy'));
    await tester.pumpAndSettle();

    expect(find.text("Change this day's bloom?"), findsOneWidget);

    await tester.tap(find.text('Change mood').last);
    await tester.pumpAndSettle();

    expect(fake.moodWrites, <({String date, Mood? mood})>[
      (date: _pastDate, mood: Mood.happy),
    ]);
  });

  testWidgets(
      'Change mood on a past day is a 48 dp target without moving the card',
      (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await _pumpPastDayCard(tester, Mood.grateful);

    final Finder label = find.text('Change mood');
    final Size hitArea = tester.getSize(
      find.ancestor(of: label, matching: find.byType(GestureDetector)).first,
    );
    final Size node = tester.getSemantics(label).rect.size;
    expect(hitArea.width, greaterThanOrEqualTo(48));
    expect(hitArea.height, greaterThanOrEqualTo(48));
    expect(node.width, greaterThanOrEqualTo(48));
    expect(node.height, greaterThanOrEqualTo(48));

    final Rect card = tester.getRect(find.byType(DayMoodCard));
    expect(card.height, 68);
    expect(tester.getRect(find.text('Felt Grateful')).top - card.top, 15);
    expect(tester.getRect(label).top - card.top, 25.5);
    handle.dispose();
  });

  testWidgets('the day card names the mood once and is not an image',
      (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await _openPastDaySheet(tester, Mood.grateful);

    expect(find.byType(DayMoodCard), findsOneWidget);
    final String summary = tester.getSemantics(find.text('Felt Grateful')).label;
    expect(
      _labelParts(summary).where((String part) => part.contains('Grateful')),
      hasLength(1),
      reason: summary,
    );
    expect(
      find.semantics
          .byPredicate(
            (SemanticsNode node) =>
                node.getSemanticsData().flagsCollection.isImage &&
                node.label.contains('Felt'),
          )
          .evaluate(),
      isEmpty,
    );
    handle.dispose();
  });
}
