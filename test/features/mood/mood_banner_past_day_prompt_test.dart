import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/mood/mood_banner_for_date.dart';
import 'package:field_notes/features/sound/sound_providers.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/state.dart';

import '../sound/support/fake_sound_player.dart';
import 'support/mood_harness.dart';

void main() {
  testWidgets("a past day asks to plant this day's bloom",
      (WidgetTester tester) async {
    final FakeJournalRepository fake = FakeJournalRepository(
      initialDay: testDay(date: '2026-07-18', mood: null),
    );
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
        child: moodHarness(const MoodBannerForDate(date: '2026-07-18')),
      ),
    );
    await tester.pump();

    expect(find.text("tap to plant this day's bloom"), findsOneWidget);
  });
}
