import 'package:field_notes/design/settings_fields/settings_fields.dart';
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
import '../support/settings_harness.dart';

Future<void> _pumpSection(
  WidgetTester tester, {
  required FakeSettingsRepository repository,
  AppSettings settings = AppSettings.defaults,
  List<String>? messages,
}) async {
  useWideSurface(tester);
  await tester.pumpWidget(
    settingsFeatureHarness(
      RemindersSoundSection(
        settings: settings,
        onFeedback: (String message) => messages?.add(message),
        pickTime: (BuildContext context, TimeOfDay initial) async => null,
      ),
      overrides: <Override>[
        settingsRepositoryProvider.overrideWithValue(repository),
        appSettingsProvider.overrideWith(
          (Ref ref) => Stream<AppSettings>.value(settings),
        ),
        entriesForDateProvider.overrideWith(
          (Ref ref, String date) => Stream<List<Entry>>.value(const <Entry>[]),
        ),
        reminderClockProvider.overrideWithValue(() => DateTime(2026, 7, 20, 9)),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Reflection question sits directly after Daily reminder and starts off',
    (WidgetTester tester) async {
      await _pumpSection(tester, repository: FakeSettingsRepository());

      expect(find.text('Reflection question'), findsOneWidget);
      expect(
        find.text('Show a gentle prompt when recording voice or video.'),
        findsOneWidget,
      );

      final SettingsToggle toggle = tester.widget<SettingsToggle>(
        find.descendant(
          of: find.widgetWithText(SettingsFieldRow, 'Reflection question'),
          matching: find.byType(SettingsToggle),
        ),
      );
      expect(toggle.value, isFalse);

      final double dailyReminderTop = tester
          .getTopLeft(find.text('Daily reminder'))
          .dy;
      final double reflectionTop = tester
          .getTopLeft(find.text('Reflection question'))
          .dy;
      final double reminderTimeTop = tester
          .getTopLeft(find.text('Reminder time'))
          .dy;

      expect(reflectionTop, greaterThan(dailyReminderTop));
      expect(reminderTimeTop, greaterThan(reflectionTop));
    },
  );

  testWidgets('turning Reflection question on writes the setting', (
    WidgetTester tester,
  ) async {
    final FakeSettingsRepository repository = FakeSettingsRepository();
    await _pumpSection(tester, repository: repository);

    await tester.tap(
      find.descendant(
        of: find.widgetWithText(SettingsFieldRow, 'Reflection question'),
        matching: find.byType(SettingsToggle),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.reflectionPromptsEnabledWrites, <bool>[true]);
  });

  testWidgets('a failed Reflection question write shows the failure notice', (
    WidgetTester tester,
  ) async {
    final List<String> messages = <String>[];
    await _pumpSection(
      tester,
      repository: FakeSettingsRepository(writeError: StateError('disk full')),
      messages: messages,
    );

    await tester.tap(
      find.descendant(
        of: find.widgetWithText(SettingsFieldRow, 'Reflection question'),
        matching: find.byType(SettingsToggle),
      ),
    );
    await tester.pumpAndSettle();

    expect(messages, <String>[
      'Could not save your reflection question setting.',
    ]);
  });
}
