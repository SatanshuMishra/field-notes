import 'package:field_notes/app/app.dart';
import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/domain/settings/settings.dart';
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
import '../../features/settings/support/fake_settings_repository.dart';
import '../support/a11y_state.dart';

const Size _sidebarSurface = Size(1280, 800);
const Size _bottomBarSurface = Size(360, 740);

const List<ShellLayout> _layouts = <ShellLayout>[
  ShellLayout.sidebar,
  ShellLayout.bottomBar,
];

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

FakeSettingsRepository _freshInstall() =>
    FakeSettingsRepository(storedValues: false);

FakeSettingsRepository _onboarded() => FakeSettingsRepository(
  initial: AppSettings.defaults.copyWith(
    onboardingStatus: OnboardingStatus.done,
    notificationPermissionAsked: true,
  ),
);

class _Screen {
  const _Screen(
    this.name, {
    required this.reach,
    required this.proof,
    this.settings = _freshInstall,
  });

  final String name;
  final void Function(OnboardingController controller) reach;
  final List<A11yProof> Function(ShellLayout layout) proof;
  final FakeSettingsRepository Function() settings;
}

String _layoutName(ShellLayout layout) => switch (layout) {
  ShellLayout.sidebar => 'sidebar',
  ShellLayout.bottomBar => 'bottom-bar',
};

List<Override> _overrides(FakeSettingsRepository settings) => <Override>[
  for (final Override override in shellOverrides())
    if (override.origin != settingsRepositoryProvider) override,
  settingsRepositoryProvider.overrideWithValue(settings),
  onboardingCountryCodeProvider.overrideWithValue('US'),
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
      controller.setNote('A first line about today');
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

void Function(OnboardingController controller) _walkTo(
  OnboardingChapter target,
) => (OnboardingController controller) {
  for (final OnboardingChapter chapter in OnboardingChapter.values) {
    if (chapter == target) {
      return;
    }
    _doTask(controller, chapter);
    controller.next();
  }
};

void _openMap(OnboardingController controller) => controller.showMap();

Future<void> _pumpScreen(
  WidgetTester tester,
  ShellLayout layout,
  _Screen screen,
) async {
  tester.view.physicalSize = switch (layout) {
    ShellLayout.sidebar => _sidebarSurface,
    ShellLayout.bottomBar => _bottomBarSurface,
  };
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  debugDefaultTargetPlatformOverride = switch (layout) {
    ShellLayout.sidebar => TargetPlatform.macOS,
    ShellLayout.bottomBar => TargetPlatform.android,
  };
  try {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(screen.settings()),
        child: const FieldNotesApp(),
      ),
    );
    await _settle(tester);
    screen.reach(
      ProviderScope.containerOf(tester.element(find.byType(AppShell)))
          .read(onboardingControllerProvider.notifier),
    );
    await _settle(tester);
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

List<A11yProof> Function(ShellLayout layout) _chapterProof(
  OnboardingChapter chapter,
) =>
    (ShellLayout layout) => <A11yProof>[
      A11yProof(find.byType(OnboardingFrame)),
      A11yProof(find.byType(_chapterTypes[chapter]!)),
      A11yProof(find.text(_titles[chapter]!)),
      A11yProof(find.byKey(onboardingProgressKey)),
    ];

List<A11yProof> _mapProof(ShellLayout layout) => <A11yProof>[
  A11yProof(find.byType(OnboardingFrame)),
  A11yProof(find.byType(TourChapter)),
  A11yProof(find.text(_titles[OnboardingChapter.tour]!)),
  A11yProof(
    find.descendant(
      of: find.byKey(onboardingPrimaryKey),
      matching: find.text('Done'),
    ),
  ),
];

final List<_Screen> _screens = <_Screen>[
  for (final OnboardingChapter chapter in OnboardingChapter.values)
    _Screen(
      chapter.name,
      reach: _walkTo(chapter),
      proof: _chapterProof(chapter),
    ),
  const _Screen(
    'map-replay',
    reach: _openMap,
    proof: _mapProof,
    settings: _onboarded,
  ),
];

final List<A11yState> onboardingStates = <A11yState>[
  for (final (int index, _Screen screen) in _screens.indexed)
    for (final (int side, ShellLayout layout) in _layouts.indexed)
      A11yState(
        id:
            'o${index * _layouts.length + side + 1}-'
            '${screen.name}-${_layoutName(layout)}',
        pump: (WidgetTester tester) => _pumpScreen(tester, layout, screen),
        proof: screen.proof(layout),
      ),
];
