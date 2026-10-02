import 'package:field_notes/app/app.dart';
import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/shell/shell_content.dart';
import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/motion/motion.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/onboarding/chapters/opening_chapter.dart';
import 'package:field_notes/features/onboarding/onboarding.dart';
import 'package:field_notes/features/reminders/reminder_providers.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:field_notes/state/shell_navigation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/capture/core/capture_test_support.dart'
    show FakeNoteWriter;
import '../../features/settings/support/fake_settings_repository.dart';
import '../../features/settings/support/recording_reminder_scheduler.dart';
import '../support/app_shell_harness.dart';

const Duration _halfFade = Duration(milliseconds: 600);
const Duration _restOfFade = Duration(milliseconds: 700);
const Duration _wholeFade = Duration(milliseconds: 1300);

typedef _Layout = ({ShellLayout layout, TargetPlatform platform, Size surface});

const List<_Layout> _layouts = <_Layout>[
  (
    layout: ShellLayout.sidebar,
    platform: TargetPlatform.macOS,
    surface: Size(1280, 800),
  ),
  (
    layout: ShellLayout.bottomBar,
    platform: TargetPlatform.android,
    surface: Size(480, 960),
  ),
];

const List<OnboardingChapter> _beforeTheYear = <OnboardingChapter>[
  OnboardingChapter.day,
  OnboardingChapter.moment,
  OnboardingChapter.month,
];

FakeSettingsRepository _onboarded() => FakeSettingsRepository(
  initial: AppSettings.defaults.copyWith(
    onboardingStatus: OnboardingStatus.done,
    notificationPermissionAsked: true,
  ),
);

FakeSettingsRepository _freshInstall() =>
    FakeSettingsRepository(storedValues: false);

Future<void> _onLayout(_Layout layout, Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = layout.platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

List<Override> _overrides(FakeSettingsRepository settings) {
  final Set<Object> replaced = <Object>{
    settingsRepositoryProvider,
    reminderSchedulerProvider,
  };
  return <Override>[
    for (final Override override in shellOverrides())
      if (!replaced.contains(override.origin)) override,
    settingsRepositoryProvider.overrideWithValue(settings),
    reminderSchedulerProvider.overrideWithValue(RecordingReminderScheduler()),
    onboardingCountryCodeProvider.overrideWithValue('US'),
    noteWriterProvider.overrideWith((Ref ref) => FakeNoteWriter()),
  ];
}

Future<void> _settle(WidgetTester tester) async {
  for (int frame = 0; frame < 4; frame++) {
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<ProviderContainer> _pumpApp(
  WidgetTester tester,
  _Layout layout,
  FakeSettingsRepository settings,
) async {
  tester.view.physicalSize = layout.surface;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: _overrides(settings),
      child: const FieldNotesApp(),
    ),
  );
  await _settle(tester);
  return ProviderScope.containerOf(tester.element(find.byType(AppShell)));
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}

Finder get _petals => find.byType(PetalDrift);

Finder get _framePetals =>
    find.descendant(of: find.byType(OnboardingFrame), matching: _petals);

double _petalOpacity(WidgetTester tester) => tester
    .widget<Opacity>(
      find.ancestor(of: _framePetals, matching: find.byType(Opacity)).first,
    )
    .opacity;

OnboardingChapter _chapter(ProviderContainer container) => (container.read(
  onboardingControllerProvider,
) as OnboardingFlowRunning).chapter;

void _doTask(OnboardingController controller, OnboardingChapter chapter) {
  switch (chapter) {
    case OnboardingChapter.moment:
      controller.setNote('A first line about today');
    case OnboardingChapter.month:
      controller.setMonthFill(1);
    case OnboardingChapter.opening ||
        OnboardingChapter.day ||
        OnboardingChapter.year ||
        OnboardingChapter.theme ||
        OnboardingChapter.reminder ||
        OnboardingChapter.week ||
        OnboardingChapter.tour:
      return;
  }
}

Future<void> _expectPetalsOnEveryPageButTheMeadow(
  WidgetTester tester,
  _Layout layout,
) async {
  final ProviderContainer container = await _pumpApp(
    tester,
    layout,
    _onboarded(),
  );
  expect(find.byType(OnboardingFrame), findsNothing);
  for (final ShellDestination page in ShellDestination.values) {
    container.read(shellNavigationProvider.notifier).select(page);
    await _settle(tester);
    final String reason = '${layout.layout.name} ${page.name}';
    expect(container.read(shellNavigationProvider), page, reason: reason);
    if (page == ShellDestination.garden) {
      expect(_petals, findsNothing, reason: reason);
    } else {
      expect(_petals, findsOneWidget, reason: reason);
      expect(
        tester.getRect(_petals),
        tester.getRect(find.byType(ShellContent)),
        reason: reason,
      );
    }
  }
  await _unmount(tester);
}

Future<void> _expectPetalsFromPlantingButNotOverTheYear(
  WidgetTester tester,
  _Layout layout,
) async {
  final String name = layout.layout.name;
  final ProviderContainer container = await _pumpApp(
    tester,
    layout,
    _freshInstall(),
  );
  final OnboardingController controller = container.read(
    onboardingControllerProvider.notifier,
  );
  expect(find.byType(OpeningChapter), findsOneWidget, reason: name);
  expect(_petals, findsNothing, reason: name);
  await tester.pump(_wholeFade);
  expect(_petals, findsNothing, reason: name);

  controller.plant();
  await tester.pump();
  expect(_framePetals, findsOneWidget, reason: name);
  expect(_petals, findsOneWidget, reason: name);
  expect(_petalOpacity(tester), lessThan(0.05), reason: name);
  await tester.pump(_halfFade);
  expect(_petalOpacity(tester), inExclusiveRange(0, 1), reason: name);
  await tester.pump(_restOfFade);
  expect(_petalOpacity(tester), 1, reason: name);

  controller.markGrown();
  for (final OnboardingChapter chapter in _beforeTheYear) {
    controller.next();
    await _settle(tester);
    final String reason = '$name ${chapter.name}';
    expect(_chapter(container), chapter, reason: reason);
    expect(_framePetals, findsOneWidget, reason: reason);
    expect(_petals, findsOneWidget, reason: reason);
    expect(_petalOpacity(tester), 1, reason: reason);
    _doTask(controller, chapter);
  }

  controller.next();
  await _settle(tester);
  expect(_chapter(container), OnboardingChapter.year, reason: name);
  await tester.pump(_wholeFade);
  expect(_petals, findsNothing, reason: '$name year');

  controller.setYearDay(365, scrubbed: true);
  controller.next();
  await _settle(tester);
  expect(_chapter(container), OnboardingChapter.theme, reason: name);
  await tester.pump(_wholeFade);
  expect(_framePetals, findsOneWidget, reason: '$name theme');
  expect(_petals, findsOneWidget, reason: '$name theme');
  expect(_petalOpacity(tester), 1, reason: '$name theme');
  await _unmount(tester);
}

void main() {
  testWidgets(
    'petals drift over every page but the Meadow and through onboarding after '
    'planting',
    (WidgetTester tester) async {
      for (final _Layout layout in _layouts) {
        await _onLayout(layout, () async {
          await _expectPetalsOnEveryPageButTheMeadow(tester, layout);
          await _expectPetalsFromPlantingButNotOverTheYear(tester, layout);
        });
      }
    },
  );
}
