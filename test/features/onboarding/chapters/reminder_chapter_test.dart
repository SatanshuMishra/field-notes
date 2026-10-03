import 'package:field_notes/app/app.dart';
import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/domain/settings/reminder_time.dart';
import 'package:field_notes/domain/settings/week_start.dart';
import 'package:field_notes/features/onboarding/chapters/reminder_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/tour_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/week_chapter.dart';
import 'package:field_notes/features/onboarding/onboarding_chapter.dart';
import 'package:field_notes/features/onboarding/onboarding_controller.dart';
import 'package:field_notes/features/onboarding/onboarding_frame.dart';
import 'package:field_notes/features/onboarding/reminder_choice.dart';
import 'package:field_notes/features/reminders/local_notifications_reminder_scheduler.dart';
import 'package:field_notes/features/reminders/notification_settings_opener.dart';
import 'package:field_notes/features/reminders/reminder_providers.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../app/support/app_shell_harness.dart';
import '../../reminders/support/fake_reminder_scheduler.dart';
import '../../settings/support/fake_settings_repository.dart';
import '../../settings/support/recording_reminder_scheduler.dart';

const String _liveTitle = 'Field Notes';
const String _liveBody = "You haven't written today's field note yet.";
const String _quietBody = 'No nudges. Your meadow waits quietly.';

const String _notificationsOff = 'Notifications are off for Field Notes.';
const String _openSettings = 'Open System Settings';
const String _goOn =
    'You can still go on. Reminders stay off until notifications are on.';
const List<String> _helpTexts = <String>[
  _notificationsOff,
  _openSettings,
  _goOn,
];

const Size _sidebarArea = Size(1280, 758);
const Size _bottomBarArea = Size(360, 740);
const Size _sidebarSurface = Size(1280, 800);
const Size _bottomBarSurface = Size(360, 740);

const ReminderTime _evening = ReminderTime(hour: 20, minute: 30);

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

typedef _Clock = ({
  bool use24Hour,
  List<String> choices,
  String big,
  String preview,
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

const List<ReminderChoice> _timedChoices = <ReminderChoice>[
  ReminderChoice.morning,
  ReminderChoice.midday,
  ReminderChoice.evening,
];

const List<_Clock> _clocks = <_Clock>[
  (
    use24Hour: false,
    choices: <String>['8:00 AM', '12:30 PM', '8:30 PM'],
    big: '8:30 PM',
    preview: '8:30 PM',
  ),
  (
    use24Hour: true,
    choices: <String>['08:00', '12:30', '20:30'],
    big: '20:30',
    preview: '20:30',
  ),
];

class _RecordingOpener implements NotificationSettingsOpener {
  int opens = 0;

  @override
  Future<void> open() async {
    opens++;
  }
}

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
  bool use24Hour = true,
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
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduceMotion,
            alwaysUse24HourFormat: use24Hour,
          ),
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

Future<void> _settle(WidgetTester tester) async {
  for (int frame = 0; frame < 4; frame++) {
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<ProviderContainer> _pumpOnboarding(
  WidgetTester tester,
  ShellLayout layout, {
  required FakeSettingsRepository settings,
  required FakeReminderScheduler scheduler,
  _RecordingOpener? opener,
}) async {
  tester.view.physicalSize = switch (layout) {
    ShellLayout.sidebar => _sidebarSurface,
    ShellLayout.bottomBar => _bottomBarSurface,
  };
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final Set<Object> replaced = <Object>{
    settingsRepositoryProvider,
    reminderSchedulerProvider,
  };
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: <Override>[
        for (final Override override in shellOverrides())
          if (!replaced.contains(override.origin)) override,
        settingsRepositoryProvider.overrideWithValue(settings),
        reminderSchedulerProvider.overrideWithValue(scheduler),
        if (opener != null)
          notificationSettingsOpenerProvider.overrideWithValue(opener),
        onboardingCountryCodeProvider.overrideWithValue('US'),
      ],
      child: const FieldNotesApp(),
    ),
  );
  await _settle(tester);
  final ProviderContainer container = ProviderScope.containerOf(
    tester.element(find.byType(AppShell)),
  );
  final OnboardingController controller = container.read(
    onboardingControllerProvider.notifier,
  );
  controller.skipToSetup();
  controller.next();
  await _settle(tester);
  expect(find.byType(ReminderChapter), findsOneWidget);
  return container;
}

OnboardingChapter _chapterOf(ProviderContainer container) => (container.read(
  onboardingControllerProvider,
) as OnboardingFlowRunning).chapter;

Future<void> _moveOn(WidgetTester tester, ShellLayout layout) async {
  switch (layout) {
    case ShellLayout.sidebar:
      await tester.tap(find.byKey(onboardingPrimaryKey));
    case ShellLayout.bottomBar:
      expect(find.byKey(onboardingPrimaryKey), findsNothing);
      await tester.flingFrom(
        tester.getCenter(find.byType(OnboardingFrame)),
        const Offset(-120, 0),
        800,
      );
  }
  await _settle(tester);
}

Future<void> _finish(WidgetTester tester, ShellLayout layout) async {
  await _moveOn(tester, layout);
  expect(find.byType(TourChapter), findsOneWidget);
  expect(
    find.descendant(
      of: find.byKey(switch (layout) {
        ShellLayout.sidebar => onboardingPrimaryKey,
        ShellLayout.bottomBar => onboardingCueKey,
      }),
      matching: find.text(switch (layout) {
        ShellLayout.sidebar => 'Start journaling',
        ShellLayout.bottomBar => 'swipe to start journaling',
      }),
    ),
    findsOneWidget,
  );
  await _moveOn(tester, layout);
  expect(find.byType(OnboardingFrame), findsNothing);
}

void _expectHelp(WidgetTester tester, {required bool shown, String? reason}) {
  for (final String text in _helpTexts) {
    expect(
      find.text(text),
      shown ? findsOneWidget : findsNothing,
      reason: '$reason $text',
    );
  }
}

Future<void> _refuse(
  WidgetTester tester,
  ShellLayout layout,
  ProviderContainer container,
  FakeReminderScheduler scheduler, {
  required String reason,
}) async {
  _expectHelp(tester, shown: false, reason: '$reason before Next');
  await _moveOn(tester, layout);
  expect(scheduler.permissionRequests, 1, reason: reason);
  expect(
    _chapterOf(container),
    OnboardingChapter.reminder,
    reason: '$reason stays',
  );
  expect(find.byType(ReminderChapter), findsOneWidget, reason: reason);
  _expectHelp(tester, shown: true, reason: reason);
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

  testWidgets("reminder times follow the device's 12-hour or 24-hour clock", (
    WidgetTester tester,
  ) async {
    for (final ShellLayout layout in ShellLayout.values) {
      await _onLayout(layout, () async {
        for (final _Clock clock in _clocks) {
          final String reason =
              '${layout.name} ${clock.use24Hour ? '24-hour' : '12-hour'}';
          await _pumpReminder(tester, layout, use24Hour: clock.use24Hour);
          await tester.pump(const Duration(seconds: 1));

          for (final (int index, ReminderChoice choice)
              in _timedChoices.indexed) {
            expect(
              find.descendant(
                of: find.byKey(reminderChoiceKey(choice)),
                matching: find.text(clock.choices[index]),
              ),
              findsOneWidget,
              reason: '$reason ${choice.name}',
            );
          }
          expect(
            tester.widget<Text>(find.byKey(reminderTimeKey)).data,
            clock.big,
            reason: reason,
          );
          expect(_inPreview(clock.preview), findsOneWidget, reason: reason);
          expect(
            find.descendant(
              of: find.byKey(reminderChoiceKey(ReminderChoice.off)),
              matching: find.text(_optionsFor(layout).last.time),
            ),
            findsOneWidget,
            reason: reason,
          );

          await _choose(tester, ReminderChoice.off);
          expect(
            tester.widget<Text>(find.byKey(reminderTimeKey)).data,
            '—',
            reason: reason,
          );
          expect(_inPreview('off'), findsOneWidget, reason: reason);
          await _unmount(tester);
        }
      });
    }
  });

  testWidgets(
    'next with a time asks for permission once and moves on when allowed',
    (WidgetTester tester) async {
      for (final ShellLayout layout in ShellLayout.values) {
        await _onLayout(layout, () async {
          final String name = layout.name;
          final FakeSettingsRepository settings = FakeSettingsRepository(
            storedValues: false,
          );
          final FakeReminderScheduler asking = FakeReminderScheduler(
            permissionGranted: false,
            grantOnRequest: true,
          );
          final ProviderContainer container = await _pumpOnboarding(
            tester,
            layout,
            settings: settings,
            scheduler: asking,
          );
          expect(_held(tester), ReminderChoice.evening, reason: name);
          expect(asking.permissionRequests, 0, reason: name);

          await _moveOn(tester, layout);
          expect(asking.permissionRequests, 1, reason: '$name 20:30');
          expect(
            _chapterOf(container),
            OnboardingChapter.week,
            reason: '$name 20:30',
          );
          expect(find.byType(WeekChapter), findsOneWidget, reason: name);
          expect(find.text(_notificationsOff), findsNothing, reason: name);
          expect(
            settings.notificationPermissionAskedWrites,
            everyElement(isTrue),
            reason: name,
          );
          expect(
            settings.notificationPermissionAskedWrites,
            isNotEmpty,
            reason: name,
          );

          final FakeSettingsRepository quietSettings = FakeSettingsRepository(
            storedValues: false,
          );
          final FakeReminderScheduler quiet = FakeReminderScheduler(
            permissionGranted: false,
          );
          final ProviderContainer off = await _pumpOnboarding(
            tester,
            layout,
            settings: quietSettings,
            scheduler: quiet,
          );
          await _choose(tester, ReminderChoice.off);
          expect(_held(tester), ReminderChoice.off, reason: name);
          await _moveOn(tester, layout);
          expect(quiet.permissionRequests, 0, reason: '$name no reminder');
          expect(
            _chapterOf(off),
            OnboardingChapter.week,
            reason: '$name no reminder',
          );
          expect(find.byType(WeekChapter), findsOneWidget, reason: name);
          expect(quietSettings.notificationPermissionAskedWrites, <bool>[
            true,
          ], reason: '$name no reminder');
          await _unmount(tester);
        });
      }
    },
  );

  testWidgets('next with permission already granted moves on without asking', (
    WidgetTester tester,
  ) async {
    for (final ShellLayout layout in ShellLayout.values) {
      await _onLayout(layout, () async {
        final String name = layout.name;
        final FakeSettingsRepository settings = FakeSettingsRepository(
          storedValues: false,
        );
        final FakeReminderScheduler granted = FakeReminderScheduler();
        final ProviderContainer container = await _pumpOnboarding(
          tester,
          layout,
          settings: settings,
          scheduler: granted,
        );
        expect(_held(tester), ReminderChoice.evening, reason: name);
        _expectHelp(tester, shown: false, reason: '$name before Next');

        await _moveOn(tester, layout);
        expect(granted.permissionRequests, 0, reason: name);
        expect(_chapterOf(container), OnboardingChapter.week, reason: name);
        expect(find.byType(WeekChapter), findsOneWidget, reason: name);
        _expectHelp(tester, shown: false, reason: '$name after Next');
        expect(settings.notificationPermissionAskedWrites, <bool>[
          true,
        ], reason: name);
        await _unmount(tester);
      });
    }
  });

  testWidgets(
    'a refusal keeps the Reminder page with the help text and Open System '
    'Settings',
    (WidgetTester tester) async {
      for (final ShellLayout layout in ShellLayout.values) {
        await _onLayout(layout, () async {
          final String name = layout.name;
          final FakeSettingsRepository settings = FakeSettingsRepository(
            storedValues: false,
          );
          final FakeReminderScheduler refusing = FakeReminderScheduler(
            permissionGranted: false,
          );
          final _RecordingOpener opener = _RecordingOpener();
          final ProviderContainer container = await _pumpOnboarding(
            tester,
            layout,
            settings: settings,
            scheduler: refusing,
            opener: opener,
          );

          await _refuse(tester, layout, container, refusing, reason: name);
          final Finder button = find.text(_openSettings);
          expect(
            tester.getSemantics(button),
            isSemantics(
              label: _openSettings,
              isButton: true,
              hasTapAction: true,
            ),
            reason: name,
          );
          await tester.tap(button);
          await _settle(tester);
          expect(opener.opens, 1, reason: name);
          expect(
            _chapterOf(container),
            OnboardingChapter.reminder,
            reason: name,
          );

          await _moveOn(tester, layout);
          expect(refusing.permissionRequests, 1, reason: '$name second Next');
          expect(
            _chapterOf(container),
            OnboardingChapter.week,
            reason: '$name second Next',
          );
          expect(find.byType(WeekChapter), findsOneWidget, reason: name);

          await _finish(tester, layout);
          expect(settings.reminderEnabledWrites, <bool>[false], reason: name);
          expect(settings.reminderTimeWrites, <ReminderTime>[
            _evening,
          ], reason: name);
          await _unmount(tester);
        });
      }
    },
  );

  testWidgets('returning with notifications on clears the help text', (
    WidgetTester tester,
  ) async {
    for (final ShellLayout layout in ShellLayout.values) {
      await _onLayout(layout, () async {
        final String name = layout.name;
        final FakeSettingsRepository settings = FakeSettingsRepository(
          storedValues: false,
        );
        final FakeReminderScheduler refusing = FakeReminderScheduler(
          permissionGranted: false,
        );
        final ProviderContainer container = await _pumpOnboarding(
          tester,
          layout,
          settings: settings,
          scheduler: refusing,
        );
        await _refuse(tester, layout, container, refusing, reason: name);

        refusing.permissionGranted = true;
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await _settle(tester);
        expect(_chapterOf(container), OnboardingChapter.reminder, reason: name);
        _expectHelp(tester, shown: false, reason: '$name resumed');

        await _moveOn(tester, layout);
        expect(find.byType(WeekChapter), findsOneWidget, reason: name);
        await _finish(tester, layout);
        expect(settings.reminderEnabledWrites, <bool>[true], reason: name);
        expect(settings.reminderTimeWrites, <ReminderTime>[
          _evening,
        ], reason: name);
        await _unmount(tester);
      });
    }
  });
}
