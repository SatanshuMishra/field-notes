import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/reminders/reminder_providers.dart';
import 'package:field_notes/features/settings/sections/reminders_sound_section.dart';
import 'package:field_notes/features/settings/widgets/reminder_time_sheet.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_settings_repository.dart';
import '../support/recording_reminder_scheduler.dart';
import '../support/settings_harness.dart';

const Size _phone = Size(384, 832);
const Size _desktop = Size(1280, 900);
const double _statusBar = 34;
const double _gestureBar = 24;

final Finder _sheet = find.byType(PhoneSheet);

Finder _inSheet(String text) =>
    find.descendant(of: _sheet, matching: find.text(text));

void _useSurface(WidgetTester tester, TargetPlatform platform) {
  final bool phone = platform == TargetPlatform.android;
  tester.view.physicalSize = phone ? _phone : _desktop;
  tester.view.devicePixelRatio = 1;
  if (phone) {
    tester.view.padding = const FakeViewPadding(
      top: _statusBar,
      bottom: _gestureBar,
    );
    tester.view.viewPadding = const FakeViewPadding(
      top: _statusBar,
      bottom: _gestureBar,
    );
  } else {
    tester.view.resetPadding();
    tester.view.resetViewPadding();
  }
  addTearDown(tester.view.reset);
}

Future<void> _pumpSection(
  WidgetTester tester,
  TargetPlatform platform,
  FakeSettingsRepository repository,
) async {
  debugDefaultTargetPlatformOverride = platform;
  _useSurface(tester, platform);
  await tester.pumpWidget(
    KeyedSubtree(
      key: UniqueKey(),
      child: settingsFeatureHarness(
        RemindersSoundSection(
          settings: AppSettings.defaults,
          onFeedback: (String message) {},
        ),
        overrides: <Override>[
          settingsRepositoryProvider.overrideWithValue(repository),
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
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the phone reminder time opens a stepper sheet and Done saves', (
    WidgetTester tester,
  ) async {
    try {
      final FakeSettingsRepository repository = FakeSettingsRepository();
      await _pumpSection(tester, TargetPlatform.android, repository);

      await tester.tap(find.byType(SettingsTimeField));
      await tester.pumpAndSettle();

      expect(_sheet, findsOneWidget);
      expect(find.byType(TimePickerDialog), findsNothing);
      expect(_inSheet(reminderTimeSheetTitle), findsOneWidget);
      final TextStyle titleStyle = tester
          .widget<Text>(_inSheet(reminderTimeSheetTitle))
          .style!;
      expect(titleStyle.fontSize, 18);
      expect(titleStyle.fontFamily, TypographyTokens.serif);
      expect(titleStyle.fontWeight, FontWeight.w500);
      expect(
        tester.getCenter(_inSheet(reminderTimeSheetTitle)).dx,
        closeTo(_phone.width / 2, 0.5),
      );

      expect(_inSheet('20'), findsOneWidget);
      expect(_inSheet('30'), findsOneWidget);
      final TextStyle digitStyle = tester.widget<Text>(_inSheet('20')).style!;
      expect(digitStyle.fontSize, 40);
      expect(digitStyle.fontFamily, TypographyTokens.serif);
      for (final String label in <String>[
        reminderTimeHourUpLabel,
        reminderTimeHourDownLabel,
        reminderTimeMinuteUpLabel,
        reminderTimeMinuteDownLabel,
      ]) {
        expect(
          tester.getSize(find.bySemanticsLabel(label)),
          const Size(64, 44),
        );
      }
      final Rect hourUp = tester.getRect(
        find.bySemanticsLabel(reminderTimeHourUpLabel),
      );
      final Rect hourDown = tester.getRect(
        find.bySemanticsLabel(reminderTimeHourDownLabel),
      );
      final Rect hours = tester.getRect(_inSheet('20'));
      expect(hours.top, greaterThan(hourUp.bottom));
      expect(hourDown.top, greaterThan(hours.bottom));
      expect(tester.getSize(find.byKey(reminderTimeSheetDoneKey)).height, 48);

      await tester.tap(find.bySemanticsLabel(reminderTimeHourUpLabel));
      await tester.pump();
      expect(_inSheet('21'), findsOneWidget);

      await tester.tap(find.byKey(reminderTimeSheetDoneKey));
      await tester.pumpAndSettle();

      expect(_sheet, findsNothing);
      expect(repository.reminderTimeWrites, <ReminderTime>[
        const ReminderTime(hour: 21, minute: 30),
      ]);

      await tester.tap(find.byType(SettingsTimeField));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel(reminderTimeMinuteDownLabel));
      await tester.pump();
      expect(_inSheet('25'), findsOneWidget);
      await tester.tapAt(const Offset(192, 60));
      await tester.pumpAndSettle();

      expect(_sheet, findsNothing);
      expect(repository.reminderTimeWrites, hasLength(1));

      final FakeSettingsRepository desktopRepository = FakeSettingsRepository();
      await _pumpSection(tester, TargetPlatform.macOS, desktopRepository);

      await tester.tap(find.byType(SettingsTimeField));
      await tester.pumpAndSettle();

      expect(_sheet, findsNothing);
      expect(find.byType(TimePickerDialog), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  test('the hour wraps through midnight and the minute steps by five', () {
    expect(
      stepReminderHour(const TimeOfDay(hour: 23, minute: 30), 1),
      const TimeOfDay(hour: 0, minute: 30),
    );
    expect(
      stepReminderHour(const TimeOfDay(hour: 0, minute: 30), -1),
      const TimeOfDay(hour: 23, minute: 30),
    );
    expect(
      stepReminderMinute(const TimeOfDay(hour: 8, minute: 55), 1),
      const TimeOfDay(hour: 8, minute: 0),
    );
    expect(
      stepReminderMinute(const TimeOfDay(hour: 8, minute: 0), -1),
      const TimeOfDay(hour: 8, minute: 55),
    );
  });
}
