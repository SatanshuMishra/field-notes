import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/reminders/reminder_providers.dart';
import 'package:field_notes/features/settings/sections/reminders_sound_section.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_settings_repository.dart';
import '../support/recording_reminder_scheduler.dart';
import '../support/settings_harness.dart';

void main() {
  testWidgets('the sound row names the sound it plays', (
    WidgetTester tester,
  ) async {
    useWideSurface(tester);
    await tester.pumpWidget(
      settingsFeatureHarness(
        RemindersSoundSection(
          settings: AppSettings.defaults,
          onFeedback: (String _) {},
          pickTime: (BuildContext context, TimeOfDay initial) async => null,
        ),
        overrides: <Override>[
          settingsRepositoryProvider.overrideWithValue(
            FakeSettingsRepository(),
          ),
          appSettingsProvider.overrideWith(
            (Ref ref) => Stream<AppSettings>.value(AppSettings.defaults),
          ),
          entriesForDateProvider.overrideWith(
            (Ref ref, String date) =>
                Stream<List<Entry>>.value(const <Entry>[]),
          ),
          reminderClockProvider.overrideWithValue(
            () => DateTime(2026, 7, 20, 9),
          ),
          reminderSchedulerProvider.overrideWithValue(
            RecordingReminderScheduler(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('A soft pencil sound when you plant a mood.'),
      findsOneWidget,
    );
  });
}
