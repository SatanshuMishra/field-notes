import 'package:field_notes/app/app.dart';
import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/domain/mood/mood.dart';
import 'package:field_notes/domain/services/note_writer.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/garden/scene/meadow_stage.dart';
import 'package:field_notes/features/onboarding/chapters/day_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/moment_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/month_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/opening_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/reminder_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/theme_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/tour_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/week_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/year_chapter.dart';
import 'package:field_notes/features/onboarding/onboarding.dart';
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
import '../support/a11y_state.dart';

const Size onboardingSidebarSurface = Size(1280, 800);
const Size onboardingBottomBarSurface = Size(360, 740);

const List<ShellLayout> _layouts = <ShellLayout>[
  ShellLayout.sidebar,
  ShellLayout.bottomBar,
];

const int _meadowFrames = 6000;
const Duration _meadowWait = Duration(milliseconds: 2);
const Duration _yearMidPlay = Duration(seconds: 4);
const Duration _yearToEnd = Duration(seconds: 12);

const String _firstLine = 'A first line about today';
const String _lineFailure =
    "Couldn't save this line. Keep typing to try again.";
const String _savedHint = 'saved to today ✓';
const String _emptyHint = 'write anything at all to keep going';
const String _lookAhead = 'drag to look ahead →';
const String _reminderOff = 'No nudges. Your meadow waits quietly.';

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
  OnboardingChapter.day: 'How was today, honestly?',
  OnboardingChapter.moment: 'Write a little about today.',
  OnboardingChapter.month: 'Give it a few weeks.',
  OnboardingChapter.year: 'This is roughly what a year of you looks like.',
  OnboardingChapter.theme: 'Daylight or lamplight?',
  OnboardingChapter.reminder: 'When should we check in?',
  OnboardingChapter.week: 'Your week starts on…',
  OnboardingChapter.tour: "Here's where everything lives.",
};

enum _Line { saves, fails }

enum _Year { untouched, playing, finished }

FakeSettingsRepository _freshInstall() =>
    FakeSettingsRepository(storedValues: false);

FakeSettingsRepository _onboarded() => FakeSettingsRepository(
  initial: AppSettings.defaults.copyWith(
    onboardingStatus: OnboardingStatus.done,
    notificationPermissionAsked: true,
  ),
);

void _stay(OnboardingController controller) {}

List<Finder> _nothingMore(ShellLayout layout) => const <Finder>[];

class _Screen {
  const _Screen(
    this.name, {
    required this.chapter,
    this.setUp = _stay,
    this.shows = _nothingMore,
    this.line = _Line.saves,
    this.year = _Year.untouched,
    this.replay = false,
  });

  final String name;
  final OnboardingChapter chapter;
  final void Function(OnboardingController controller) setUp;
  final List<Finder> Function(ShellLayout layout) shows;
  final _Line line;
  final _Year year;
  final bool replay;
}

String _layoutName(ShellLayout layout) => switch (layout) {
  ShellLayout.sidebar => 'sidebar',
  ShellLayout.bottomBar => 'bottom-bar',
};

FakeNoteWriter _writer(_Line line) => switch (line) {
  _Line.saves => FakeNoteWriter(),
  _Line.fails => FakeNoteWriter(failure: const NoteWriteException('disk full')),
};

List<Override> _overrides(_Screen screen) => <Override>[
  for (final Override override in shellOverrides())
    if (override.origin != settingsRepositoryProvider) override,
  settingsRepositoryProvider.overrideWithValue(
    screen.replay ? _onboarded() : _freshInstall(),
  ),
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

void _walkTo(OnboardingController controller, OnboardingChapter target) {
  for (final OnboardingChapter chapter in OnboardingChapter.values) {
    if (chapter == target) {
      return;
    }
    _doTask(controller, chapter);
    controller.next();
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

Future<void> _pumpScreen(
  WidgetTester tester,
  ShellLayout layout,
  Size surface,
  _Screen screen,
) async {
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
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
      _walkTo(controller, screen.chapter);
      screen.setUp(controller);
    }
    await _settle(tester);
    await _growYear(tester, screen.year);
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

Finder _primaryLabelled(String label) => find.descendant(
  of: find.byKey(onboardingPrimaryKey),
  matching: find.text(label),
);

List<A11yProof> _proof(_Screen screen, ShellLayout layout) => <A11yProof>[
  A11yProof(find.byType(OnboardingFrame)),
  A11yProof(find.byType(_chapterTypes[screen.chapter]!)),
  A11yProof(find.text(_titles[screen.chapter]!)),
  if (!screen.replay) A11yProof(find.byKey(onboardingProgressKey)),
  for (final Finder finder in screen.shows(layout)) A11yProof(finder),
];

final List<_Screen> _screens = <_Screen>[
  _Screen(
    'opening-unplanted',
    chapter: OnboardingChapter.opening,
    shows: (ShellLayout layout) => <Finder>[
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
      _primaryLabelled(onboardingBeginLabel),
    ],
  ),
  _Screen(
    'day-happy',
    chapter: OnboardingChapter.day,
    shows: (ShellLayout layout) => <Finder>[
      find.descendant(
        of: find.byKey(dayCardKey),
        matching: find.text(Mood.happy.label),
      ),
    ],
  ),
  _Screen(
    'day-calm',
    chapter: OnboardingChapter.day,
    setUp: (OnboardingController controller) =>
        controller.chooseMood(Mood.calm),
    shows: (ShellLayout layout) => <Finder>[
      find.descendant(
        of: find.byKey(dayCardKey),
        matching: find.text(Mood.calm.label),
      ),
    ],
  ),
  _Screen(
    'moment-empty',
    chapter: OnboardingChapter.moment,
    shows: (ShellLayout layout) => <Finder>[
      find.byKey(momentFieldKey),
      find.text(_emptyHint),
    ],
  ),
  _Screen(
    'moment-saved',
    chapter: OnboardingChapter.moment,
    setUp: (OnboardingController controller) => controller.setNote(_firstLine),
    shows: (ShellLayout layout) => <Finder>[
      find.text(_savedHint),
      find.byKey(momentMediaKey),
    ],
  ),
  _Screen(
    'moment-failed',
    chapter: OnboardingChapter.moment,
    line: _Line.fails,
    setUp: (OnboardingController controller) => controller.setNote(_firstLine),
    shows: (ShellLayout layout) => <Finder>[find.text(_lineFailure)],
  ),
  _Screen(
    'month-empty',
    chapter: OnboardingChapter.month,
    shows: (ShellLayout layout) => <Finder>[
      find.byKey(monthSliderKey),
      find.text(_lookAhead),
    ],
  ),
  _Screen(
    'month-full',
    chapter: OnboardingChapter.month,
    setUp: (OnboardingController controller) => controller.setMonthFill(1),
    shows: (ShellLayout layout) => <Finder>[
      find.byKey(monthSliderKey),
      find.textContaining('by the end of'),
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
    ],
  ),
  _Screen(
    'theme',
    chapter: OnboardingChapter.theme,
    shows: (ShellLayout layout) => <Finder>[
      for (final Appearance appearance in Appearance.values)
        find.byKey(themeChoiceKey(appearance)),
    ],
  ),
  _Screen(
    'reminder-time',
    chapter: OnboardingChapter.reminder,
    shows: (ShellLayout layout) => <Finder>[
      find.byKey(reminderPreviewKey),
      find.byKey(reminderChoiceKey(ReminderChoice.evening)),
    ],
  ),
  _Screen(
    'reminder-off',
    chapter: OnboardingChapter.reminder,
    setUp: (OnboardingController controller) =>
        controller.chooseReminder(ReminderChoice.off),
    shows: (ShellLayout layout) => <Finder>[find.text(_reminderOff)],
  ),
  _Screen(
    'week',
    chapter: OnboardingChapter.week,
    shows: (ShellLayout layout) => <Finder>[find.byKey(weekStripKey)],
  ),
  _Screen(
    'map-end',
    chapter: OnboardingChapter.tour,
    shows: (ShellLayout layout) => <Finder>[
      _primaryLabelled(switch (layout) {
        ShellLayout.sidebar => onboardingStartLabelSidebar,
        ShellLayout.bottomBar => onboardingStartLabelBottomBar,
      }),
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
