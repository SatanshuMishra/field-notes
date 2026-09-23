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

void main() {
  testWidgets('writes the chosen mood for the date and shows it',
      (WidgetTester tester) async {
    final FakeJournalRepository fake =
        FakeJournalRepository(initialDay: testDay(mood: null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          journalRepositoryProvider.overrideWithValue(fake),
          appSettingsProvider.overrideWith(
            (Ref ref) => Stream<AppSettings>.value(AppSettings.defaults),
          ),
          soundPlayerProvider.overrideWithValue(FakeSoundPlayer()),
          todayClockProvider.overrideWithValue(() => DateTime(2026, 7, 19, 9)),
        ],
        child: moodHarness(const MoodBannerForDate(date: '2026-07-19')),
      ),
    );
    await tester.pump();

    expect(find.text('How are you feeling today?'), findsOneWidget);

    await tester.tap(find.text('How are you feeling today?'));
    await tester.pumpAndSettle();
    expect(find.text('How are you feeling?'), findsOneWidget);

    await tester.tap(find.text('Calm'));
    await tester.pumpAndSettle();

    expect(fake.moodWrites, <({String date, Mood? mood})>[
      (date: '2026-07-19', mood: Mood.calm),
    ]);
    expect(find.text('Feeling Calm today'), findsOneWidget);
    expect(find.text('change'), findsOneWidget);
  });

  testWidgets('surfaces a non-destructive error when the write fails',
      (WidgetTester tester) async {
    final FakeJournalRepository fake =
        FakeJournalRepository(initialDay: testDay(mood: null))
          ..setMoodError = Exception('disk full');
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          journalRepositoryProvider.overrideWithValue(fake),
          appSettingsProvider.overrideWith(
            (Ref ref) => Stream<AppSettings>.value(AppSettings.defaults),
          ),
          soundPlayerProvider.overrideWithValue(FakeSoundPlayer()),
        ],
        child: moodHarness(const MoodBannerForDate(date: '2026-07-19')),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('How are you feeling today?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calm'));
    await tester.pumpAndSettle();

    expect(fake.moodWrites, isEmpty);
    expect(
      find.text("Couldn't save your mood. Please try again."),
      findsOneWidget,
    );
    expect(find.text('How are you feeling today?'), findsOneWidget);
  });
}
