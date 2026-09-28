import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/reminders/notification_settings_opener.dart';
import 'package:field_notes/features/reminders/reminder_providers.dart';
import 'package:field_notes/features/reminders/reminder_scheduler.dart';
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

class _RecordingOpener implements NotificationSettingsOpener {
  int opens = 0;

  @override
  Future<void> open() async => opens++;
}

Future<void> _pumpSection(
  WidgetTester tester, {
  required FakeSettingsRepository repository,
  AppSettings settings = AppSettings.defaults,
  List<String>? messages,
  TimeOfDayPicker? pickTime,
  RecordingReminderScheduler? scheduler,
  NotificationSettingsOpener? opener,
}) async {
  useWideSurface(tester);
  await tester.pumpWidget(
    settingsFeatureHarness(
      RemindersSoundSection(
        settings: settings,
        onFeedback: (String message) => messages?.add(message),
        pickTime: pickTime ??
            (BuildContext context, TimeOfDay initial) async => null,
      ),
      overrides: <Override>[
        settingsRepositoryProvider.overrideWithValue(repository),
        appSettingsProvider.overrideWith(
          (Ref ref) => Stream<AppSettings>.value(settings),
        ),
        entriesForDateProvider.overrideWith(
          (Ref ref, String date) => Stream<List<Entry>>.value(
            const <Entry>[],
          ),
        ),
        reminderClockProvider.overrideWithValue(
          () => DateTime(2026, 7, 20, 9),
        ),
        if (scheduler != null)
          reminderSchedulerProvider.overrideWithValue(scheduler),
        if (opener != null)
          notificationSettingsOpenerProvider.overrideWithValue(opener),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders the reminder and sound controls',
      (WidgetTester tester) async {
    await _pumpSection(tester, repository: FakeSettingsRepository());

    expect(find.text('Reminders & sound'), findsOneWidget);
    expect(find.text('Daily reminder'), findsOneWidget);
    expect(find.text('Reminder time'), findsOneWidget);
    expect(find.text('8:30 PM'), findsOneWidget);
    expect(find.text('Sound effects'), findsOneWidget);
  });

  testWidgets('toggling the daily reminder writes the setting',
      (WidgetTester tester) async {
    final FakeSettingsRepository repository = FakeSettingsRepository();
    await _pumpSection(tester, repository: repository);

    await tester.tap(find.byType(SettingsToggle).first);
    await tester.pumpAndSettle();

    expect(repository.reminderEnabledWrites, <bool>[false]);
  });

  testWidgets('toggling sound effects writes the setting',
      (WidgetTester tester) async {
    final FakeSettingsRepository repository = FakeSettingsRepository();
    await _pumpSection(tester, repository: repository);

    await tester.tap(find.byType(SettingsToggle).last);
    await tester.pumpAndSettle();

    expect(repository.soundEnabledWrites, <bool>[false]);
  });

  testWidgets('picking a reminder time writes the chosen time',
      (WidgetTester tester) async {
    final FakeSettingsRepository repository = FakeSettingsRepository();
    await _pumpSection(
      tester,
      repository: repository,
      pickTime: (BuildContext context, TimeOfDay initial) async =>
          const TimeOfDay(hour: 7, minute: 5),
    );

    await tester.tap(find.byType(SettingsTimeField));
    await tester.pumpAndSettle();

    expect(
      repository.reminderTimeWrites,
      <ReminderTime>[const ReminderTime(hour: 7, minute: 5)],
    );
  });

  testWidgets('a dismissed time picker writes nothing',
      (WidgetTester tester) async {
    final FakeSettingsRepository repository = FakeSettingsRepository();
    await _pumpSection(tester, repository: repository);

    await tester.tap(find.byType(SettingsTimeField));
    await tester.pumpAndSettle();

    expect(repository.reminderTimeWrites, isEmpty);
  });

  testWidgets('a failed write is reported to the feedback sink',
      (WidgetTester tester) async {
    final List<String> messages = <String>[];
    await _pumpSection(
      tester,
      repository: FakeSettingsRepository(writeError: StateError('disk full')),
      messages: messages,
    );

    await tester.tap(find.byType(SettingsToggle).first);
    await tester.pumpAndSettle();

    expect(messages, <String>['Could not save your daily reminder setting.']);
  });

  testWidgets('settings no longer books reminders itself',
      (WidgetTester tester) async {
    final RecordingReminderScheduler scheduler = RecordingReminderScheduler();
    await _pumpSection(
      tester,
      repository: FakeSettingsRepository(),
      scheduler: scheduler,
    );

    expect(scheduler.bookings, isEmpty);
    expect(scheduler.cancelCount, 0);
  });

  testWidgets(
      'a refused permission says notifications are off and offers Open System Settings',
      (WidgetTester tester) async {
    final _RecordingOpener opener = _RecordingOpener();
    await _pumpSection(
      tester,
      repository: FakeSettingsRepository(),
      scheduler: RecordingReminderScheduler(
        permission: ReminderPermission.denied,
      ),
      opener: opener,
    );

    expect(find.text('Notifications are off for Field Notes.'), findsOneWidget);
    expect(
      tester.widget<SettingsToggle>(find.byType(SettingsToggle).first).value,
      isTrue,
    );

    await tester.tap(find.widgetWithText(StickerButton, 'Open System Settings'));
    await tester.pumpAndSettle();

    expect(opener.opens, 1);
  });

  testWidgets('turning the reminder on asks for a permission not yet granted',
      (WidgetTester tester) async {
    final FakeSettingsRepository repository = FakeSettingsRepository();
    final RecordingReminderScheduler scheduler = RecordingReminderScheduler(
      permission: ReminderPermission.denied,
    );
    await _pumpSection(
      tester,
      repository: repository,
      settings: AppSettings.defaults.copyWith(reminderEnabled: false),
      scheduler: scheduler,
    );

    await tester.tap(find.byType(SettingsToggle).first);
    await tester.pumpAndSettle();

    expect(repository.reminderEnabledWrites, <bool>[true]);
    expect(scheduler.permissionRequests, 1);
    expect(repository.notificationPermissionAskedWrites, <bool>[true]);
  });
}
