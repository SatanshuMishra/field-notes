import 'dart:async';

import 'package:field_notes/app/app.dart';
import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/motion/motion.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/onboarding/onboarding.dart';
import 'package:field_notes/features/reminders/reminder_providers.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/capture/core/capture_test_support.dart'
    show FakeNoteWriter;
import '../../features/settings/support/fake_settings_repository.dart';
import '../../features/settings/support/recording_reminder_scheduler.dart';
import '../support/app_shell_harness.dart';

const Duration _tick = Duration(milliseconds: 250);
const Duration _idleSpan = Duration(minutes: 5);
const double _mostFramesAsked = 0.25;
const double _fewestOnboardingFramesAsked = 0.99;
const Duration _growthStep = Duration(milliseconds: 100);
const int _growthSteps = 200;
const int _finishSteps = 100;

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

const _Layout _bottomBar = (
  layout: ShellLayout.bottomBar,
  platform: TargetPlatform.android,
  surface: Size(480, 960),
);

class _TodayJournal extends FakeJournalRepository {
  final StreamController<Day?> _days = StreamController<Day?>.broadcast();
  Day? _today;

  Mood? get todayMood => _today?.mood;

  @override
  Stream<Day?> watchDayForDate(String date) async* {
    yield _today;
    yield* _days.stream;
  }

  @override
  Future<Day> setMoodForDate({required String date, Mood? mood}) async {
    final Day day = Day(
      id: 'today',
      date: date,
      mood: mood,
      createdAt: 0,
      updatedAt: 0,
    );
    _today = day;
    _days.add(day);
    return day;
  }
}

FakeSettingsRepository _onboarded() => FakeSettingsRepository(
  initial: AppSettings.defaults.copyWith(
    onboardingStatus: OnboardingStatus.done,
    notificationPermissionAsked: true,
  ),
);

FakeSettingsRepository _freshInstall() =>
    FakeSettingsRepository(storedValues: false);

List<Override> _overrides(
  _TodayJournal journal,
  FakeSettingsRepository settings,
) {
  final Set<Object> replaced = <Object>{
    settingsRepositoryProvider,
    reminderSchedulerProvider,
    journalRepositoryProvider,
  };
  return <Override>[
    for (final Override override in shellOverrides())
      if (!replaced.contains(override.origin)) override,
    settingsRepositoryProvider.overrideWithValue(settings),
    reminderSchedulerProvider.overrideWithValue(RecordingReminderScheduler()),
    journalRepositoryProvider.overrideWithValue(journal),
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
  _TodayJournal journal,
  FakeSettingsRepository settings,
) async {
  tester.view.physicalSize = layout.surface;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: _overrides(journal, settings),
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

Future<double> _shareOfTicksAskingForFrames(WidgetTester tester) async {
  final int ticks = _idleSpan.inMilliseconds ~/ _tick.inMilliseconds;
  int asked = 0;
  for (int tick = 0; tick < ticks; tick++) {
    await tester.pump(_tick);
    if (tester.binding.hasScheduledFrame) {
      asked++;
    }
  }
  return asked / ticks;
}

String _percent(double share) => '${(share * 100).toStringAsFixed(1)}%';

Future<void> _expectAppPetalsRest(WidgetTester tester, String name) async {
  final double share = await _shareOfTicksAskingForFrames(tester);
  expect(
    share,
    lessThanOrEqualTo(_mostFramesAsked),
    reason:
        '$name: the idle app asked for frames on '
        '${_percent(share)} of five minutes',
  );
}

Future<void> _expectIdleAppWithABloomRests(
  WidgetTester tester,
  _Layout layout,
) async {
  final String name = layout.layout.name;
  final _TodayJournal journal = _TodayJournal();
  final ProviderContainer container = await _pumpApp(
    tester,
    layout,
    journal,
    _onboarded(),
  );
  await journal.setMoodForDate(
    date: container.read(todayDateProvider),
    mood: Mood.grateful,
  );
  await _settle(tester);
  expect(find.byType(PetalDrift), findsOneWidget, reason: name);
  expect(
    tester.widget<PetalDrift>(find.byType(PetalDrift)).flower,
    isNotNull,
    reason: '$name has no petals to drift',
  );

  await _expectAppPetalsRest(tester, name);
  await _unmount(tester);
}

Finder get _framePetals => find.descendant(
  of: find.byType(OnboardingFrame),
  matching: find.byType(PetalDrift),
);

bool _grown(ProviderContainer container) =>
    switch (container.read(onboardingControllerProvider)) {
      OnboardingFlowRunning(:final OnboardingDraft draft) => draft.grown,
      OnboardingFlowHidden() || OnboardingFlowMap() => false,
    };

bool _peonyPetalsShown(WidgetTester tester) =>
    _framePetals.evaluate().length == 1 &&
    tester.widget<PetalDrift>(_framePetals).flower == FlowerKind.peony;

OnboardingChapter? _chapter(ProviderContainer container) =>
    switch (container.read(onboardingControllerProvider)) {
      OnboardingFlowRunning(:final OnboardingChapter chapter) => chapter,
      OnboardingFlowHidden() || OnboardingFlowMap() => null,
    };

Future<void> _expectOnboardingFallsThenAppRests(WidgetTester tester) async {
  final String name = _bottomBar.layout.name;
  final _TodayJournal journal = _TodayJournal();
  final ProviderContainer container = await _pumpApp(
    tester,
    _bottomBar,
    journal,
    _freshInstall(),
  );
  final OnboardingController controller = container.read(
    onboardingControllerProvider.notifier,
  );
  expect(_chapter(container), OnboardingChapter.opening, reason: name);

  controller.plant();
  await tester.pump();
  for (
    int step = 0;
    step < _growthSteps && !(_grown(container) && _peonyPetalsShown(tester));
    step++
  ) {
    await tester.pump(_growthStep);
  }
  expect(_grown(container), isTrue, reason: '$name: the peony never grew');
  expect(
    _peonyPetalsShown(tester),
    isTrue,
    reason: '$name: the onboarding frame never showed peony petals',
  );

  final double onboarding = await _shareOfTicksAskingForFrames(tester);
  expect(
    onboarding,
    greaterThanOrEqualTo(_fewestOnboardingFramesAsked),
    reason:
        '$name: onboarding petals asked for frames on only '
        '${_percent(onboarding)} of five minutes',
  );

  unawaited(controller.next());
  await _settle(tester);
  expect(_chapter(container), OnboardingChapter.day, reason: name);
  controller.chooseMood(Mood.grateful);
  await tester.pump();
  unawaited(controller.next());
  await _settle(tester);
  unawaited(controller.finish());
  for (
    int step = 0;
    step < _finishSteps &&
        container.read(onboardingControllerProvider) is! OnboardingFlowHidden;
    step++
  ) {
    await tester.pump(_growthStep);
  }
  expect(
    container.read(onboardingControllerProvider),
    isA<OnboardingFlowHidden>(),
    reason: '$name: onboarding never finished',
  );
  await _settle(tester);

  expect(journal.todayMood, Mood.grateful, reason: name);
  expect(find.byType(OnboardingFrame), findsNothing, reason: name);
  expect(find.byType(PetalDrift), findsOneWidget, reason: name);
  expect(
    tester.widget<PetalDrift>(find.byType(PetalDrift)).flower,
    isNotNull,
    reason: '$name has no petals over the app',
  );
  await _expectAppPetalsRest(tester, '$name after onboarding');
  await _unmount(tester);
}

void main() {
  testWidgets(
    'an idle app with a bloom today asks for frames at most a quarter of five '
    'minutes',
    (WidgetTester tester) async {
      for (final _Layout layout in _layouts) {
        debugDefaultTargetPlatformOverride = layout.platform;
        try {
          await _expectIdleAppWithABloomRests(tester, layout);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      }
    },
  );

  testWidgets(
    'onboarding petals keep falling through five idle minutes and the app '
    'petals rest once it finishes',
    (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = _bottomBar.platform;
      try {
        await _expectOnboardingFallsThenAppRests(tester);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
