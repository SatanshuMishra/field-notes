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

const String _date = '2026-07-19';

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

Future<void> _pumpBanner(
  WidgetTester tester, {
  required FakeJournalRepository repository,
  required FakeSoundPlayer player,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: _overrides(repository: repository, player: player),
      child: moodHarness(const MoodBannerForDate(date: _date)),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('cancelling the confirm leaves the existing bloom untouched',
      (WidgetTester tester) async {
    final FakeJournalRepository fake =
        FakeJournalRepository(initialDay: testDay(mood: Mood.calm));
    final FakeSoundPlayer player = FakeSoundPlayer();
    await _pumpBanner(tester, repository: fake, player: player);

    await tester.tap(find.text('change'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Happy'));
    await tester.pumpAndSettle();

    expect(find.text("Change today's bloom?"), findsOneWidget);
    expect(
      find.text(
        'Set today to Peony · Happy? '
        'Your current bloom will be replaced.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(fake.moodWrites, isEmpty);
    expect(player.played, isEmpty);
    expect(find.text('Mood planted · Peony'), findsNothing);
    expect(find.text('Feeling Calm today'), findsOneWidget);
  });

  testWidgets('confirming plants the mood with a cue and a toast',
      (WidgetTester tester) async {
    final FakeJournalRepository fake =
        FakeJournalRepository(initialDay: testDay(mood: Mood.calm));
    final FakeSoundPlayer player = FakeSoundPlayer();
    await _pumpBanner(tester, repository: fake, player: player);

    await tester.tap(find.text('change'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Happy'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Change mood'));
    await tester.pumpAndSettle();

    expect(fake.moodWrites, <({String date, Mood? mood})>[
      (date: _date, mood: Mood.happy),
    ]);
    expect(player.played, <String>['sounds/pencil.wav']);
    expect(find.text('Mood planted · Peony'), findsOneWidget);
  });

  testWidgets('a day with no bloom is planted without a confirm',
      (WidgetTester tester) async {
    final FakeJournalRepository fake =
        FakeJournalRepository(initialDay: testDay(mood: null));
    final FakeSoundPlayer player = FakeSoundPlayer();
    await _pumpBanner(tester, repository: fake, player: player);

    await tester.tap(find.text('How are you feeling today?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Happy'));
    await tester.pumpAndSettle();

    expect(find.text("Change today's bloom?"), findsNothing);
    expect(fake.moodWrites, <({String date, Mood? mood})>[
      (date: _date, mood: Mood.happy),
    ]);
    expect(player.played, <String>['sounds/pencil.wav']);
    expect(find.text('Mood planted · Peony'), findsOneWidget);
  });
}
