import 'dart:math' as math;

import 'package:field_notes/app/theme/app_theme.dart';
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
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_settings_repository.dart';
import '../support/recording_reminder_scheduler.dart';
import '../support/settings_harness.dart';

const double _minTapTarget = 48;

class _RecordingOpener implements NotificationSettingsOpener {
  int opens = 0;

  @override
  Future<void> open() async => opens++;
}

Rect _globalRect(SemanticsNode node) =>
    <SemanticsNode>[
      for (SemanticsNode? at = node; at != null; at = at.parent) at,
    ].fold(
      node.rect,
      (Rect rect, SemanticsNode at) => switch (at.transform) {
        final Matrix4 transform => MatrixUtils.transformRect(transform, rect),
        null => rect,
      },
    );

Future<void> _pumpSection(
  WidgetTester tester, {
  required FakeSettingsRepository repository,
  AppSettings settings = AppSettings.defaults,
  List<String>? messages,
  TimeOfDayPicker? pickTime,
  RecordingReminderScheduler? scheduler,
  NotificationSettingsOpener? opener,
  TargetPlatform? platform,
}) async {
  useWideSurface(tester);
  Widget section = RemindersSoundSection(
    settings: settings,
    onFeedback: (String message) => messages?.add(message),
    pickTime:
        pickTime ?? (BuildContext context, TimeOfDay initial) async => null,
  );
  if (platform != null) {
    section = Theme(
      data: fieldNotesTheme(platform: platform),
      child: section,
    );
  }
  await tester.pumpWidget(
    settingsFeatureHarness(
      section,
      overrides: <Override>[
        settingsRepositoryProvider.overrideWithValue(repository),
        appSettingsProvider.overrideWith(
          (Ref ref) => Stream<AppSettings>.value(settings),
        ),
        entriesForDateProvider.overrideWith(
          (Ref ref, String date) => Stream<List<Entry>>.value(const <Entry>[]),
        ),
        reminderClockProvider.overrideWithValue(() => DateTime(2026, 7, 20, 9)),
        if (scheduler != null)
          reminderSchedulerProvider.overrideWithValue(scheduler),
        if (opener != null)
          notificationSettingsOpenerProvider.overrideWithValue(opener),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

double _top(WidgetTester tester, String text) =>
    tester.getTopLeft(find.text(text)).dy;

void main() {
  testWidgets(
    'desktop reminder rows sit in daily nudge, while recording and sound groups',
    (WidgetTester tester) async {
      await _pumpSection(
        tester,
        repository: FakeSettingsRepository(),
        platform: TargetPlatform.macOS,
      );

      final List<String> order = <String>[
        'daily nudge',
        'Daily reminder',
        'Reminder time',
        'while recording',
        'Reflection question',
        'sound',
        'Sound effects',
      ];
      for (final String text in order) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      for (int index = 1; index < order.length; index++) {
        expect(
          _top(tester, order[index]),
          greaterThan(_top(tester, order[index - 1])),
          reason: '${order[index]} below ${order[index - 1]}',
        );
      }
      expect(find.text('Reminders & sound'), findsNothing);
      expect(find.text('Notifications are off for Field Notes.'), findsNothing);
    },
  );

  testWidgets('desktop notifications-off row sits under daily nudge', (
    WidgetTester tester,
  ) async {
    final _RecordingOpener opener = _RecordingOpener();
    await _pumpSection(
      tester,
      repository: FakeSettingsRepository(),
      scheduler: RecordingReminderScheduler(
        permission: ReminderPermission.denied,
      ),
      opener: opener,
      platform: TargetPlatform.macOS,
    );

    expect(
      _top(tester, 'Notifications are off for Field Notes.'),
      greaterThan(_top(tester, 'Reminder time')),
    );
    expect(
      _top(tester, 'Notifications are off for Field Notes.'),
      lessThan(_top(tester, 'while recording')),
    );
    final Finder button = find.widgetWithText(
      SettingsActionButton,
      'Open System Settings',
    );
    expect(
      tester.widget<SettingsActionButton>(button).tone,
      SettingsActionTone.neutral,
    );
    expect(
      find.widgetWithText(StickerButton, 'Open System Settings'),
      findsNothing,
    );

    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(opener.opens, 1);
  });

  testWidgets('phone reminder rows share one untitled card', (
    WidgetTester tester,
  ) async {
    await _pumpSection(
      tester,
      repository: FakeSettingsRepository(),
      platform: TargetPlatform.android,
    );

    expect(find.byType(StickerCard), findsOneWidget);
    for (final String label in <String>[
      'Reminders & sound',
      'daily nudge',
      'while recording',
      'sound',
    ]) {
      expect(find.text(label), findsNothing, reason: label);
    }
    for (final String row in <String>[
      'Daily reminder',
      'Reminder time',
      'Reflection question',
      'Sound effects',
    ]) {
      expect(find.text(row), findsOneWidget, reason: row);
    }
  });

  testWidgets('renders the reminder and sound controls', (
    WidgetTester tester,
  ) async {
    await _pumpSection(tester, repository: FakeSettingsRepository());

    expect(find.text('Reminders & sound'), findsNothing);
    expect(find.text('daily nudge'), findsNothing);
    expect(find.text('Daily reminder'), findsOneWidget);
    expect(find.text('Reminder time'), findsOneWidget);
    expect(find.text('8:30 PM'), findsOneWidget);
    expect(find.text('Sound effects'), findsOneWidget);
  });

  testWidgets('toggling the daily reminder writes the setting', (
    WidgetTester tester,
  ) async {
    final FakeSettingsRepository repository = FakeSettingsRepository();
    await _pumpSection(tester, repository: repository);

    await tester.tap(find.byType(SettingsToggle).first);
    await tester.pumpAndSettle();

    expect(repository.reminderEnabledWrites, <bool>[false]);
  });

  testWidgets('toggling sound effects writes the setting', (
    WidgetTester tester,
  ) async {
    final FakeSettingsRepository repository = FakeSettingsRepository();
    await _pumpSection(tester, repository: repository);

    await tester.tap(find.byType(SettingsToggle).last);
    await tester.pumpAndSettle();

    expect(repository.soundEnabledWrites, <bool>[false]);
  });

  testWidgets('picking a reminder time writes the chosen time', (
    WidgetTester tester,
  ) async {
    final FakeSettingsRepository repository = FakeSettingsRepository();
    await _pumpSection(
      tester,
      repository: repository,
      pickTime: (BuildContext context, TimeOfDay initial) async =>
          const TimeOfDay(hour: 7, minute: 5),
    );

    await tester.tap(find.byType(SettingsTimeField));
    await tester.pumpAndSettle();

    expect(repository.reminderTimeWrites, <ReminderTime>[
      const ReminderTime(hour: 7, minute: 5),
    ]);
  });

  testWidgets('a dismissed time picker writes nothing', (
    WidgetTester tester,
  ) async {
    final FakeSettingsRepository repository = FakeSettingsRepository();
    await _pumpSection(tester, repository: repository);

    await tester.tap(find.byType(SettingsTimeField));
    await tester.pumpAndSettle();

    expect(repository.reminderTimeWrites, isEmpty);
  });

  testWidgets('a failed write is reported to the feedback sink', (
    WidgetTester tester,
  ) async {
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

  testWidgets('settings no longer books reminders itself', (
    WidgetTester tester,
  ) async {
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

      expect(
        find.text('Notifications are off for Field Notes.'),
        findsOneWidget,
      );
      expect(
        tester.widget<SettingsToggle>(find.byType(SettingsToggle).first).value,
        isTrue,
      );

      await tester.tap(
        find.widgetWithText(StickerButton, 'Open System Settings'),
      );
      await tester.pumpAndSettle();

      expect(opener.opens, 1);
    },
  );

  testWidgets('the Open System Settings button is its own 48 dp target', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await _pumpSection(
      tester,
      repository: FakeSettingsRepository(),
      scheduler: RecordingReminderScheduler(
        permission: ReminderPermission.denied,
      ),
      opener: _RecordingOpener(),
    );

    final Rect node = _globalRect(
      tester.getSemantics(find.bySemanticsLabel('Open System Settings')),
    );
    final Rect painted = tester.getRect(
      find
          .descendant(
            of: find.widgetWithText(StickerButton, 'Open System Settings'),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final Rect target = Rect.fromCenter(
      center: painted.center,
      width: math.max(painted.width, _minTapTarget),
      height: math.max(painted.height, _minTapTarget),
    );

    expect(node.width, greaterThanOrEqualTo(_minTapTarget));
    expect(node.height, greaterThanOrEqualTo(_minTapTarget));
    expect(
      target.inflate(0.01).intersect(node),
      node,
      reason: 'node $node lies outside $target',
    );
    handle.dispose();
  });

  testWidgets('turning the reminder on asks for a permission not yet granted', (
    WidgetTester tester,
  ) async {
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
