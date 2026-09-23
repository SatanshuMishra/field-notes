import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/domain/mood/mood.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/mood/mood_banner_for_date.dart';
import 'package:field_notes/features/sound/sound_providers.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/state.dart';

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
}
