import 'dart:async';

import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/reminders/reminder_providers.dart';
import 'package:field_notes/features/settings/sections/data_section.dart';
import 'package:field_notes/features/settings/sections/journal_section.dart';
import 'package:field_notes/features/settings/sections/reminders_sound_section.dart';
import 'package:field_notes/features/settings/sections/sync_storage_section.dart';
import 'package:field_notes/features/settings/settings_screen.dart';
import 'package:field_notes/features/settings/widgets/settings_notice.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_settings_repository.dart';
import 'support/recording_reminder_scheduler.dart';
import 'support/settings_harness.dart';

Future<void> _pumpScreen(
  WidgetTester tester, {
  required FakeSettingsRepository repository,
  Stream<AppSettings>? settingsStream,
}) async {
  useWideSurface(tester);
  await tester.pumpWidget(
    settingsFeatureHarness(
      const SettingsScreen(),
      scrollable: false,
      overrides: <Override>[
        settingsRepositoryProvider.overrideWithValue(repository),
        appSettingsProvider.overrideWith(
          (Ref ref) =>
              settingsStream ?? Stream<AppSettings>.value(AppSettings.defaults),
        ),
        entriesForDateProvider.overrideWith(
          (Ref ref, String date) => Stream<List<Entry>>.value(const <Entry>[]),
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
}

void main() {
  testWidgets('shows every settings section once loaded',
      (WidgetTester tester) async {
    await _pumpScreen(tester, repository: FakeSettingsRepository());

    expect(find.byType(SyncStorageSection), findsOneWidget);
    expect(find.byType(RemindersSoundSection), findsOneWidget);
    expect(find.byType(JournalSection), findsOneWidget);
    expect(find.byType(DataSection), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('shows the placeholder while settings are still loading',
      (WidgetTester tester) async {
    final StreamController<AppSettings> pending =
        StreamController<AppSettings>();
    addTearDown(pending.close);

    await _pumpScreen(
      tester,
      repository: FakeSettingsRepository(),
      settingsStream: pending.stream,
    );

    expect(find.byType(CrossHatchPlaceholder), findsOneWidget);
    expect(find.byType(SyncStorageSection), findsNothing);
    expect(find.text('Settings'), findsNothing);
  });

  testWidgets('shows a recoverable message when settings cannot load',
      (WidgetTester tester) async {
    await _pumpScreen(
      tester,
      repository: FakeSettingsRepository(),
      settingsStream: Stream<AppSettings>.error(StateError('db gone')),
    );

    expect(find.text('Your settings could not be loaded.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.byType(SyncStorageSection), findsNothing);
  });

  testWidgets('surfaces a failed write as a dismissible notice',
      (WidgetTester tester) async {
    await _pumpScreen(
      tester,
      repository: FakeSettingsRepository(writeError: StateError('disk full')),
    );

    await tester.tap(find.byType(SettingsToggle).first);
    await tester.pumpAndSettle();

    expect(find.byType(SettingsNotice), findsOneWidget);
    expect(
      find.text('Could not save your daily reminder setting.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsNotice), findsNothing);
  });
}
