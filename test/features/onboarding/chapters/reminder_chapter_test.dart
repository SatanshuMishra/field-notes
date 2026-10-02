import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/domain/settings/week_start.dart';
import 'package:field_notes/features/onboarding/chapters/reminder_chapter.dart';
import 'package:field_notes/features/onboarding/onboarding_chapter.dart';
import 'package:field_notes/features/onboarding/onboarding_controller.dart';
import 'package:field_notes/features/onboarding/reminder_choice.dart';
import 'package:field_notes/features/reminders/local_notifications_reminder_scheduler.dart';
import 'package:field_notes/features/reminders/reminder_providers.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../app/support/app_shell_harness.dart';
import '../../settings/support/fake_settings_repository.dart';
import '../../settings/support/recording_reminder_scheduler.dart';

const String _liveTitle = 'Field Notes';
const String _liveBody = "You haven't written today's field note yet.";
const String _quietBody = 'No nudges. Your meadow waits quietly.';

const Size _sidebarArea = Size(1280, 758);
const Size _bottomBarArea = Size(360, 740);

typedef _Option = ({
  ReminderChoice choice,
  String time,
  String caption,
  String label,
});

typedef _Spies = ({
  FakeSettingsRepository settings,
  RecordingReminderScheduler scheduler,
});

const List<_Option> _sidebarOptions = <_Option>[
  (
    choice: ReminderChoice.morning,
    time: '08:00',
    caption: 'morning',
    label: '08:00, morning',
  ),
  (
    choice: ReminderChoice.midday,
    time: '12:30',
    caption: 'midday',
    label: '12:30, midday',
  ),
  (
    choice: ReminderChoice.evening,
    time: '20:30',
    caption: 'evening',
    label: '20:30, evening',
  ),
  (
    choice: ReminderChoice.off,
    time: 'Off',
    caption: 'no nudge',
    label: 'Off, no nudge',
  ),
];

const List<_Option> _bottomBarOptions = <_Option>[
  (
    choice: ReminderChoice.morning,
    time: '08:00',
    caption: 'Morning · start the day',
    label: '08:00, Morning, start the day',
  ),
  (
    choice: ReminderChoice.midday,
    time: '12:30',
    caption: 'Midday · a pause',
    label: '12:30, Midday, a pause',
  ),
  (
    choice: ReminderChoice.evening,
    time: '20:30',
    caption: 'Evening · look back',
    label: '20:30, Evening, look back',
  ),
  (
    choice: ReminderChoice.off,
    time: 'No reminder',
    caption: "You'll open it when you want",
    label: "No reminder, You'll open it when you want",
  ),
];

List<_Option> _optionsFor(ShellLayout layout) => switch (layout) {
  ShellLayout.sidebar => _sidebarOptions,
  ShellLayout.bottomBar => _bottomBarOptions,
};

Future<void> _onLayout(ShellLayout layout, Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = switch (layout) {
    ShellLayout.sidebar => TargetPlatform.macOS,
    ShellLayout.bottomBar => TargetPlatform.android,
  };
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

Future<_Spies> _pumpReminder(
  WidgetTester tester,
  ShellLayout layout, {
  bool reduceMotion = false,
}) async {
  tester.view.physicalSize = switch (layout) {
    ShellLayout.sidebar => _sidebarArea,
    ShellLayout.bottomBar => _bottomBarArea,
  };
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final FakeSettingsRepository settings = FakeSettingsRepository();
  final RecordingReminderScheduler scheduler = RecordingReminderScheduler();
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: <Override>[
        for (final Override override in shellOverrides())
          if (override.origin != settingsRepositoryProvider &&
              override.origin != reminderSchedulerProvider)
            override,
        settingsRepositoryProvider.overrideWithValue(settings),
        reminderSchedulerProvider.overrideWithValue(scheduler),
        onboardingControllerProvider.overrideWithBuild(
          (Ref ref, OnboardingController controller) =>
              const OnboardingFlowRunning(
                chapter: OnboardingChapter.reminder,
                draft: OnboardingDraft(
                  entryDate: '2026-10-14',
                  regionWeek: WeekStart.sunday,
                  week: WeekStart.sunday,
                ),
              ),
        ),
      ],
      child: MaterialApp(
        theme: fieldNotesTheme(platform: defaultTargetPlatform),
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
        home: Material(child: ReminderChapter(layout: layout)),
      ),
    ),
  );
  return (settings: settings, scheduler: scheduler);
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}

ReminderChoice? _held(WidgetTester tester) => switch (ProviderScope.containerOf(
  tester.element(find.byType(ReminderChapter)),
).read(onboardingControllerProvider)) {
  OnboardingFlowRunning(:final OnboardingDraft draft) => draft.reminder,
  OnboardingFlowHidden() || OnboardingFlowMap() => null,
};

Finder get _preview => find.byKey(reminderPreviewKey);

Finder _inPreview(String text) =>
    find.descendant(of: _preview, matching: find.text(text));

Iterable<double> _opacitiesAbove(WidgetTester tester, Finder finder) => tester
    .widgetList<Opacity>(
      find.ancestor(of: finder, matching: find.byType(Opacity)),
    )
    .map((Opacity opacity) => opacity.opacity);

void _expectPreview(
  WidgetTester tester, {
  required String big,
  required String clock,
  required String body,
  required bool quiet,
}) {
  expect(tester.widget<Text>(find.byKey(reminderTimeKey)).data, big);
  expect(_inPreview(reminderNotificationTitle), findsOneWidget);
  expect(_inPreview(clock), findsOneWidget);
  expect(_inPreview(body), findsOneWidget);
  expect(
    find.descendant(of: _preview, matching: find.byType(ColorFiltered)),
    quiet ? findsOneWidget : findsNothing,
  );
}

void _expectChoices(
  WidgetTester tester,
  ShellLayout layout,
  ReminderChoice selected,
) {
  for (final _Option option in _optionsFor(layout)) {
    final Finder control = find.byKey(reminderChoiceKey(option.choice));
    final bool on = option.choice == selected;
    expect(
      find.descendant(of: control, matching: find.text(option.time)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: control, matching: find.text(option.caption)),
      findsOneWidget,
    );
    expect(tester.getSize(control).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(control).height, greaterThanOrEqualTo(48));
    expect(tester.getSemantics(control), switch (layout) {
      ShellLayout.sidebar => isSemantics(
        label: option.label,
        isButton: true,
        isSelected: on,
        hasTapAction: true,
      ),
      ShellLayout.bottomBar => isSemantics(
        label: option.label,
        hasCheckedState: true,
        isChecked: on,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    });
  }
}

void _expectNothingSaved(_Spies spies) {
  expect(spies.settings.reminderEnabledWrites, isEmpty);
  expect(spies.settings.reminderTimeWrites, isEmpty);
  expect(spies.settings.weekStartWrites, isEmpty);
  expect(spies.settings.notificationPermissionAskedWrites, isEmpty);
  expect(spies.settings.onboardingStatusWrites, isEmpty);
  expect(spies.scheduler.permissionRequests, 0);
  expect(spies.scheduler.bookings, isEmpty);
}

Future<void> _choose(WidgetTester tester, ReminderChoice choice) async {
  await tester.tap(find.byKey(reminderChoiceKey(choice)));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('reminder previews the live notification text and holds the '
      'choice', (WidgetTester tester) async {
    expect(reminderNotificationTitle, _liveTitle);
    expect(reminderNotificationBody, _liveBody);
    for (final ShellLayout layout in ShellLayout.values) {
      await _onLayout(layout, () async {
        final _Spies spies = await _pumpReminder(tester, layout);
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('and you'), findsOneWidget);
        expect(find.text('When should we check in?'), findsOneWidget);
        expect(_held(tester), ReminderChoice.evening);
        _expectChoices(tester, layout, ReminderChoice.evening);
        _expectPreview(
          tester,
          big: '20:30',
          clock: '20:30',
          body: reminderNotificationBody,
          quiet: false,
        );
        expect(find.text(_quietBody), findsNothing);

        await _choose(tester, ReminderChoice.off);
        expect(_held(tester), ReminderChoice.off);
        _expectChoices(tester, layout, ReminderChoice.off);
        _expectPreview(
          tester,
          big: '—',
          clock: 'off',
          body: _quietBody,
          quiet: true,
        );
        expect(find.text(reminderNotificationBody), findsNothing);
        expect(find.text('20:30'), findsOneWidget);

        await _choose(tester, ReminderChoice.morning);
        expect(_held(tester), ReminderChoice.morning);
        _expectChoices(tester, layout, ReminderChoice.morning);
        _expectPreview(
          tester,
          big: '08:00',
          clock: '08:00',
          body: reminderNotificationBody,
          quiet: false,
        );
        expect(find.text(_quietBody), findsNothing);

        _expectNothingSaved(spies);
        await _unmount(tester);
      });
    }
  });

  testWidgets('reminder skips every entrance with reduce motion', (
    WidgetTester tester,
  ) async {
    for (final ShellLayout layout in ShellLayout.values) {
      await _onLayout(layout, () async {
        final _Spies spies = await _pumpReminder(
          tester,
          layout,
          reduceMotion: true,
        );
        await tester.pump();

        expect(tester.hasRunningAnimations, isFalse);
        expect(
          _opacitiesAbove(tester, find.text('When should we check in?')),
          everyElement(1),
        );
        expect(
          _opacitiesAbove(tester, _inPreview(reminderNotificationBody)),
          everyElement(1),
        );
        expect(
          _opacitiesAbove(
            tester,
            find.byKey(reminderChoiceKey(ReminderChoice.midday)),
          ),
          everyElement(1),
        );

        await tester.tap(find.byKey(reminderChoiceKey(ReminderChoice.midday)));
        await tester.pump();

        expect(tester.hasRunningAnimations, isFalse);
        expect(_held(tester), ReminderChoice.midday);
        _expectPreview(
          tester,
          big: '12:30',
          clock: '12:30',
          body: reminderNotificationBody,
          quiet: false,
        );
        expect(
          _opacitiesAbove(tester, _inPreview(reminderNotificationBody)),
          everyElement(1),
        );
        _expectNothingSaved(spies);
        await _unmount(tester);
      });
    }
  });

  testWidgets('reminder choices are labelled targets of at least 48 points', (
    WidgetTester tester,
  ) async {
    for (final ShellLayout layout in ShellLayout.values) {
      await _onLayout(layout, () async {
        await _pumpReminder(tester, layout);
        await tester.pump(const Duration(seconds: 1));

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await _unmount(tester);
      });
    }
  });
}
