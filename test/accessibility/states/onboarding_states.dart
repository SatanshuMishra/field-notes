import 'package:field_notes/app/app.dart';
import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/glass/glass.dart';
import 'package:field_notes/domain/mood/mood.dart';
import 'package:field_notes/domain/services/note_writer.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/garden/scene/meadow_stage.dart';
import 'package:field_notes/features/onboarding/chapters/day_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/garden_scene.dart';
import 'package:field_notes/features/onboarding/chapters/moment_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/month_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/opening_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/other_ways_panel.dart';
import 'package:field_notes/features/onboarding/chapters/reminder_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/theme_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/tour_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/week_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/year_chapter.dart';
import 'package:field_notes/features/onboarding/onboarding.dart';
import 'package:field_notes/features/reminders/reminder_providers.dart';
import 'package:field_notes/features/reminders/reminder_scheduler.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../app/support/app_shell_harness.dart' show shellOverrides;
import '../../features/capture/core/capture_test_support.dart'
    show FakeNoteWriter;
import '../../features/settings/support/fake_settings_repository.dart';
import '../../features/settings/support/recording_reminder_scheduler.dart';
import '../support/a11y_state.dart';

const Size onboardingSidebarSurface = Size(1280, 800);
const Size onboardingBottomBarSurface = Size(384, 832);
const double onboardingStatusBar = 34;
const double onboardingGestureBar = 24;

const List<ShellLayout> _layouts = <ShellLayout>[
  ShellLayout.sidebar,
  ShellLayout.bottomBar,
];

const int _meadowFrames = 6000;
const Duration _meadowWait = Duration(milliseconds: 2);
const Duration _yearMidPlay = Duration(seconds: 4);
const Duration _yearToEnd = Duration(seconds: 12);

const double _swipe = 120;
const double _swipeSpeed = 800;

const String _firstLine = 'A first line about today';
const String _lineFailure =
    "Couldn't save this line. Keep typing to try again.";
const String _savedHint = 'saved to today ✓';
const String _emptyHint = 'write anything at all to keep going';
const String _lookAhead = 'drag to look ahead →';
const String _reminderOff = 'No nudges. Your meadow waits quietly.';
const String _notificationsOff = 'Notifications are off for Field Notes.';
const String _openSystemSettings = 'Open System Settings';
const String _goOnWithout =
    'You can still go on. Reminders stay off until notifications are on.';
const String _otherWaysTitle = 'Some days are easier said.';

const Map<OnboardingChapter, Type> _chapterTypes = <OnboardingChapter, Type>{
  OnboardingChapter.opening: OpeningChapter,
  OnboardingChapter.day: DayChapter,
  OnboardingChapter.moment: MomentChapter,
  OnboardingChapter.month: MonthChapter,
  OnboardingChapter.year: YearChapter,
  OnboardingChapter.theme: ThemeChapter,
  OnboardingChapter.reminder: ReminderChapter,
  OnboardingChapter.week: WeekChapter,
  OnboardingChapter.tour: TourChapter,
};

const Map<OnboardingChapter, String> _titles = <OnboardingChapter, String>{
  OnboardingChapter.opening: "Most days won't feel like a story.",
  OnboardingChapter.day: 'Every feeling grows its own flower.',
  OnboardingChapter.moment: 'Write a little about today.',
  OnboardingChapter.month: 'Give it a few weeks.',
  OnboardingChapter.year: 'This is roughly what a year of you looks like.',
  OnboardingChapter.theme: 'Daylight or lamplight?',
  OnboardingChapter.reminder: 'When should we check in?',
  OnboardingChapter.week: 'Your week starts on…',
  OnboardingChapter.tour: "Here's where everything lives.",
};

typedef _Page = ({Type widget, String title});

const _Page _otherWaysPage = (widget: OtherWaysPanel, title: _otherWaysTitle);

enum _Line { saves, fails }

enum _Year { untouched, playing, finished }

enum _Notifications { allowed, refused }

FakeSettingsRepository _freshInstall() =>
    FakeSettingsRepository(storedValues: false);

FakeSettingsRepository _onboarded() => FakeSettingsRepository(
  initial: AppSettings.defaults.copyWith(
    onboardingStatus: OnboardingStatus.done,
    notificationPermissionAsked: true,
  ),
);

void _stay(OnboardingController controller) {}

Future<void> _still(WidgetTester tester, OnboardingChapter chapter) async {}

Future<void> _swipeForward(
  WidgetTester tester,
  OnboardingChapter chapter,
) async {
  await tester.flingFrom(
    tester.getCenter(find.text(_titles[chapter]!)),
    const Offset(-_swipe, 0),
    _swipeSpeed,
  );
  await _settle(tester);
}

List<Finder> _nothingMore(ShellLayout layout) => const <Finder>[];

class _Screen {
  const _Screen(
    this.name, {
    required this.chapter,
    this.setUp = _stay,
    this.shows = _nothingMore,
    this.phoneAct = _still,
    this.phonePage,
    this.line = _Line.saves,
    this.year = _Year.untouched,
    this.notifications = _Notifications.allowed,
    this.replay = false,
  });

  final String name;
  final OnboardingChapter chapter;
  final void Function(OnboardingController controller) setUp;
  final List<Finder> Function(ShellLayout layout) shows;
  final Future<void> Function(WidgetTester tester, OnboardingChapter chapter)
  phoneAct;
  final _Page? phonePage;
  final _Line line;
  final _Year year;
  final _Notifications notifications;
  final bool replay;

  _Page pageOn(ShellLayout layout) => switch ((layout, phonePage)) {
    (ShellLayout.bottomBar, final _Page page?) => page,
    _ => (widget: _chapterTypes[chapter]!, title: _titles[chapter]!),
  };
}

String _layoutName(ShellLayout layout) => switch (layout) {
  ShellLayout.sidebar => 'sidebar',
  ShellLayout.bottomBar => 'bottom-bar',
};

FakeNoteWriter _writer(_Line line) => switch (line) {
  _Line.saves => FakeNoteWriter(),
  _Line.fails => FakeNoteWriter(failure: const NoteWriteException('disk full')),
};

RecordingReminderScheduler _scheduler(_Notifications notifications) =>
    switch (notifications) {
      _Notifications.allowed => RecordingReminderScheduler(),
      _Notifications.refused => RecordingReminderScheduler(
        permission: ReminderPermission.denied,
      ),
    };

List<Override> _overrides(_Screen screen) => <Override>[
  for (final Override override in shellOverrides())
    if (override.origin != settingsRepositoryProvider &&
        override.origin != reminderSchedulerProvider)
      override,
  settingsRepositoryProvider.overrideWithValue(
    screen.replay ? _onboarded() : _freshInstall(),
  ),
  reminderSchedulerProvider.overrideWithValue(_scheduler(screen.notifications)),
  onboardingCountryCodeProvider.overrideWithValue('US'),
  noteWriterProvider.overrideWith((Ref ref) => _writer(screen.line)),
];

Future<void> _settle(WidgetTester tester) async {
  for (int frame = 0; frame < 4; frame++) {
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 300));
}

void _doTask(OnboardingController controller, OnboardingChapter chapter) {
  switch (chapter) {
    case OnboardingChapter.opening:
      controller
        ..plant()
        ..markGrown();
    case OnboardingChapter.moment:
      controller.setNote(_firstLine);
    case OnboardingChapter.month:
      controller.setMonthFill(1);
    case OnboardingChapter.year:
      controller.setYearDay(365, scrubbed: false);
    case OnboardingChapter.day ||
        OnboardingChapter.theme ||
        OnboardingChapter.reminder ||
        OnboardingChapter.week ||
        OnboardingChapter.tour:
      return;
  }
}

Future<void> _walkTo(
  WidgetTester tester,
  OnboardingController controller,
  OnboardingChapter target,
) async {
  for (final OnboardingChapter chapter in OnboardingChapter.values) {
    if (chapter == target) {
      return;
    }
    _doTask(controller, chapter);
    controller.next();
    if (chapter == OnboardingChapter.reminder) {
      await tester.pump();
    }
  }
}

Future<void> _growYear(WidgetTester tester, _Year year) async {
  if (year == _Year.untouched) {
    return;
  }
  final MeadowStageState stage = tester.state<MeadowStageState>(
    find.byType(MeadowStage),
  );
  for (int frame = 0; frame < _meadowFrames && !stage.debugIsReady; frame++) {
    await tester.runAsync(() => Future<void>.delayed(_meadowWait));
    await tester.pump();
  }
  if (!stage.debugIsReady) {
    throw StateError('the meadow never finished building');
  }
  await tester.pump();
  await tester.pump(switch (year) {
    _Year.playing => _yearMidPlay,
    _Year.finished || _Year.untouched => _yearToEnd,
  });
  await _settle(tester);
}

void _placeOn(WidgetTester tester, ShellLayout layout, Size surface) {
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1;
  switch (layout) {
    case ShellLayout.sidebar:
      tester.view.resetPadding();
      tester.view.resetViewPadding();
    case ShellLayout.bottomBar:
      const FakeViewPadding insets = FakeViewPadding(
        top: onboardingStatusBar,
        bottom: onboardingGestureBar,
      );
      tester.view.padding = insets;
      tester.view.viewPadding = insets;
  }
  addTearDown(tester.view.reset);
}

Future<void> _pumpScreen(
  WidgetTester tester,
  ShellLayout layout,
  Size surface,
  _Screen screen,
) async {
  _placeOn(tester, layout, surface);
  debugDefaultTargetPlatformOverride = switch (layout) {
    ShellLayout.sidebar => TargetPlatform.macOS,
    ShellLayout.bottomBar => TargetPlatform.android,
  };
  try {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(screen),
        child: const FieldNotesApp(),
      ),
    );
    await _settle(tester);
    final OnboardingController controller = ProviderScope.containerOf(
      tester.element(find.byType(AppShell)),
    ).read(onboardingControllerProvider.notifier);
    if (screen.replay) {
      controller.showMap();
    } else {
      await _walkTo(tester, controller, screen.chapter);
      screen.setUp(controller);
    }
    await _settle(tester);
    if (layout == ShellLayout.bottomBar) {
      await screen.phoneAct(tester, screen.chapter);
    }
    await _growYear(tester, screen.year);
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

Finder _primaryLabelled(String label) => find.descendant(
  of: find.byKey(onboardingPrimaryKey),
  matching: find.text(label),
);

Finder _cueReading(String label) => find.descendant(
  of: find.byKey(onboardingCueKey),
  matching: find.text(label),
);

List<Finder> _planted(Mood mood) => <Finder>[
  find.byKey(gardenSceneKey),
  find.byKey(gardenFlowerKey(mood.flower)),
  find.byKey(gardenRootsKey(mood.flower)),
  find.descendant(
    of: find.byKey(gardenStakeKey),
    matching: find.text(mood.flower.label.toLowerCase()),
  ),
];

List<Finder> _chrome(_Screen screen, ShellLayout layout) => <Finder>[
  find.byKey(onboardingProgressKey),
  find.byKey(onboardingToggleKey),
  if (screen.chapter.isStory) find.byKey(onboardingSkipKey),
  if (screen.chapter != OnboardingChapter.opening)
    switch (layout) {
      ShellLayout.sidebar => find.descendant(
        of: find.byKey(onboardingBackKey),
        matching: find.byType(GlassSurface),
      ),
      ShellLayout.bottomBar => find.byKey(onboardingBackKey),
    },
  if (layout == ShellLayout.bottomBar) find.byKey(onboardingCueKey),
];

List<A11yProof> _proof(_Screen screen, ShellLayout layout) {
  final _Page page = screen.pageOn(layout);
  return <A11yProof>[
    A11yProof(find.byType(OnboardingFrame)),
    A11yProof(find.byType(page.widget)),
    A11yProof(find.text(page.title)),
    if (!screen.replay)
      for (final Finder finder in _chrome(screen, layout)) A11yProof(finder),
    for (final Finder finder in screen.shows(layout)) A11yProof(finder),
  ];
}

final List<_Screen> _screens = <_Screen>[
  _Screen(
    'opening-unplanted',
    chapter: OnboardingChapter.opening,
    shows: (ShellLayout layout) => <Finder>[
      find.byKey(gardenSceneKey),
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Semantics &&
            widget.properties.label == 'Plant your first seed',
      ),
      find.text(switch (layout) {
        ShellLayout.sidebar => 'click anywhere to plant your first seed',
        ShellLayout.bottomBar => 'tap anywhere to plant your first seed',
      }),
    ],
  ),
  _Screen(
    'opening-grown',
    chapter: OnboardingChapter.opening,
    setUp: (OnboardingController controller) => controller
      ..plant()
      ..markGrown(),
    shows: (ShellLayout layout) => <Finder>[
      find.byKey(gardenSceneKey),
      switch (layout) {
        ShellLayout.sidebar => _primaryLabelled(onboardingBeginLabel),
        ShellLayout.bottomBar => _cueReading(onboardingSwipeOnLabel),
      },
    ],
  ),
  _Screen(
    'day-happy',
    chapter: OnboardingChapter.day,
    shows: (ShellLayout layout) => <Finder>[
      find.byKey(dayMoodGridKey),
      find.byKey(dayMoodKey(Mood.happy)),
      ..._planted(Mood.happy),
    ],
  ),
  _Screen(
    'day-calm',
    chapter: OnboardingChapter.day,
    setUp: (OnboardingController controller) =>
        controller.chooseMood(Mood.calm),
    shows: (ShellLayout layout) => <Finder>[
      find.byKey(dayMoodGridKey),
      find.byKey(dayMoodKey(Mood.calm)),
      ..._planted(Mood.calm),
    ],
  ),
  _Screen(
    'moment-empty',
    chapter: OnboardingChapter.moment,
    phoneAct: _swipeForward,
    shows: (ShellLayout layout) => <Finder>[
      find.byKey(momentFieldKey),
      find.text(_emptyHint),
      if (layout == ShellLayout.bottomBar) ...<Finder>[
        _cueReading(onboardingMomentCue),
        find.byKey(onboardingToastKey),
        find.text(onboardingMomentFirst),
      ],
    ],
  ),
  _Screen(
    'moment-saved',
    chapter: OnboardingChapter.moment,
    setUp: (OnboardingController controller) => controller.setNote(_firstLine),
    phoneAct: _swipeForward,
    phonePage: _otherWaysPage,
    shows: (ShellLayout layout) => switch (layout) {
      ShellLayout.sidebar => <Finder>[
        find.text(_savedHint),
        find.byKey(momentMediaKey),
      ],
      ShellLayout.bottomBar => <Finder>[
        find.byKey(otherWaysSpeakKey),
        find.byKey(otherWaysFilmKey),
        find.byKey(otherWaysSnapKey),
        _cueReading(onboardingSwipeOnLabel),
      ],
    },
  ),
  _Screen(
    'moment-failed',
    chapter: OnboardingChapter.moment,
    line: _Line.fails,
    setUp: (OnboardingController controller) => controller.setNote(_firstLine),
    shows: (ShellLayout layout) => <Finder>[
      find.byKey(momentFieldKey),
      find.text(_lineFailure),
    ],
  ),
  _Screen(
    'month-empty',
    chapter: OnboardingChapter.month,
    shows: (ShellLayout layout) => <Finder>[
      find.byKey(monthSliderKey),
      find.text(_lookAhead),
      if (layout == ShellLayout.bottomBar) _cueReading(onboardingMonthCue),
    ],
  ),
  _Screen(
    'month-full',
    chapter: OnboardingChapter.month,
    setUp: (OnboardingController controller) => controller.setMonthFill(1),
    shows: (ShellLayout layout) => <Finder>[
      find.byKey(monthSliderKey),
      find.textContaining('by the end of'),
      if (layout == ShellLayout.bottomBar) _cueReading(onboardingSwipeOnLabel),
    ],
  ),
  _Screen(
    'year-playing',
    chapter: OnboardingChapter.year,
    year: _Year.playing,
    shows: (ShellLayout layout) => <Finder>[
      find.byKey(yearSliderKey),
      find.byKey(yearReplayKey),
      find.textContaining(' of 365 days'),
      if (layout == ShellLayout.bottomBar) _cueReading(onboardingYearCue),
    ],
  ),
  _Screen(
    'year-finished',
    chapter: OnboardingChapter.year,
    year: _Year.finished,
    shows: (ShellLayout layout) => <Finder>[
      find.byKey(yearSliderKey),
      find.byKey(yearReplayKey),
      find.text(yearWholeLabel),
      find.text(switch (layout) {
        ShellLayout.sidebar => yearCaptionSidebar,
        ShellLayout.bottomBar => yearCaptionBottomBar,
      }),
      if (layout == ShellLayout.bottomBar) _cueReading(onboardingSwipeOnLabel),
    ],
  ),
  _Screen(
    'theme',
    chapter: OnboardingChapter.theme,
    shows: (ShellLayout layout) => <Finder>[
      for (final Appearance appearance in Appearance.values)
        find.byKey(themeChoiceKey(appearance)),
      if (layout == ShellLayout.bottomBar) ...<Finder>[
        find.byKey(themePreviewKey),
        _cueReading(onboardingSwipeOnLabel),
      ],
    ],
  ),
  _Screen(
    'reminder-time',
    chapter: OnboardingChapter.reminder,
    shows: (ShellLayout layout) => <Finder>[
      find.byKey(reminderPreviewKey),
      find.byKey(reminderChoiceKey(ReminderChoice.evening)),
      if (layout == ShellLayout.bottomBar) _cueReading(onboardingSwipeOnLabel),
    ],
  ),
  _Screen(
    'reminder-off',
    chapter: OnboardingChapter.reminder,
    setUp: (OnboardingController controller) =>
        controller.chooseReminder(ReminderChoice.off),
    shows: (ShellLayout layout) => <Finder>[
      find.text(_reminderOff),
      if (layout == ShellLayout.bottomBar) _cueReading(onboardingSwipeOnLabel),
    ],
  ),
  _Screen(
    'week',
    chapter: OnboardingChapter.week,
    shows: (ShellLayout layout) => <Finder>[
      find.byKey(weekStripKey),
      if (layout == ShellLayout.bottomBar) _cueReading(onboardingSwipeOnLabel),
    ],
  ),
  _Screen(
    'map-end',
    chapter: OnboardingChapter.tour,
    shows: (ShellLayout layout) => <Finder>[
      switch (layout) {
        ShellLayout.sidebar => _primaryLabelled(onboardingStartLabelSidebar),
        ShellLayout.bottomBar => _cueReading(onboardingSwipeLastLabel),
      },
    ],
  ),
  _Screen(
    'map-replay',
    chapter: OnboardingChapter.tour,
    replay: true,
    shows: (ShellLayout layout) => <Finder>[
      _primaryLabelled(onboardingDoneLabel),
    ],
  ),
  _Screen(
    'reminder-notifications-off',
    chapter: OnboardingChapter.reminder,
    notifications: _Notifications.refused,
    setUp: (OnboardingController controller) => controller.next(),
    shows: (ShellLayout layout) => <Finder>[
      find.text(_notificationsOff),
      find.text(_openSystemSettings),
      find.text(_goOnWithout),
      switch (layout) {
        ShellLayout.sidebar => _primaryLabelled(onboardingNextLabel),
        ShellLayout.bottomBar => _cueReading(onboardingSwipeOnLabel),
      },
    ],
  ),
];

List<A11yState> onboardingStatesAt({
  required Size sidebar,
  required Size bottomBar,
}) => <A11yState>[
  for (final (int index, _Screen screen) in _screens.indexed)
    for (final (int side, ShellLayout layout) in _layouts.indexed)
      A11yState(
        id:
            'o${index * _layouts.length + side + 1}-'
            '${screen.name}-${_layoutName(layout)}',
        pump: (WidgetTester tester) =>
            _pumpScreen(tester, layout, switch (layout) {
              ShellLayout.sidebar => sidebar,
              ShellLayout.bottomBar => bottomBar,
            }, screen),
        proof: _proof(screen, layout),
      ),
];

final List<A11yState> onboardingStates = onboardingStatesAt(
  sidebar: onboardingSidebarSurface,
  bottomBar: onboardingBottomBarSurface,
);
