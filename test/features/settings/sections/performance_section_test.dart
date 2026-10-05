import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/reminders/reminder_providers.dart';
import 'package:field_notes/features/settings/sections/performance_section.dart';
import 'package:field_notes/features/settings/settings_screen.dart';
import 'package:field_notes/features/settings/spell_check_availability.dart';
import 'package:field_notes/features/settings/widgets/settings_tabs.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/sync_overrides.dart';
import '../support/fake_settings_repository.dart';
import '../support/recording_reminder_scheduler.dart';
import '../support/settings_harness.dart';

const String _rowLabel = 'Pause the Meadow in the background';
const String _rowDescription =
    "Stops the Meadow's motion while Field Notes is open but another window or app is in front. Saves battery.";

Future<void> _pumpScreen(
  WidgetTester tester, {
  required FakeSettingsRepository repository,
}) async {
  useWideSurface(tester);
  await tester.pumpWidget(
    settingsFeatureHarness(
      const SettingsScreen(),
      scrollable: false,
      overrides: <Override>[
        settingsRepositoryProvider.overrideWithValue(repository),
        entriesForDateProvider.overrideWith(
          (Ref ref, String date) => Stream<List<Entry>>.value(const <Entry>[]),
        ),
        reminderClockProvider.overrideWithValue(() => DateTime(2026, 7, 20, 9)),
        reminderSchedulerProvider.overrideWithValue(
          RecordingReminderScheduler(),
        ),
        spellCheckAvailabilityProvider.overrideWithValue(
          const AsyncValue<SpellCheckAvailability>.data(
            SpellCheckAvailability.available,
          ),
        ),
        ...syncOffOverrides(),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

SettingsToggle _toggle(WidgetTester tester) {
  return tester.widget<SettingsToggle>(find.byKey(meadowPauseToggleKey));
}

void main() {
  testWidgets("the Journal tab's Performance section pauses the Meadow in the "
      'background by default and saves a change', (WidgetTester tester) async {
    final FakeSettingsRepository repository = FakeSettingsRepository();
    await _pumpScreen(tester, repository: repository);

    expect(SettingsTab.values, hasLength(4));
    expect(find.byKey(meadowPauseToggleKey), findsNothing);

    await tester.tap(find.byKey(settingsTabKey(SettingsTab.journal)));
    await tester.pumpAndSettle();

    expect(find.text('Performance'), findsOneWidget);
    expect(find.text(_rowLabel), findsOneWidget);
    expect(find.text(_rowDescription), findsOneWidget);
    expect(
      tester.getRect(find.text('Spell check')).top,
      lessThan(tester.getRect(find.text('Performance')).top),
    );
    expect(_toggle(tester).semanticLabel, _rowLabel);
    expect(_toggle(tester).value, isTrue);

    await tester.tap(find.byKey(meadowPauseToggleKey));
    await tester.pumpAndSettle();

    expect(repository.meadowPausesWhenInactiveWrites, <bool>[false]);
    expect(_toggle(tester).value, isFalse);
  });
}
