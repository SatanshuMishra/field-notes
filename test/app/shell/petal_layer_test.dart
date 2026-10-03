import 'dart:async';

import 'package:field_notes/app/app.dart';
import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/shell/bottom_bar_shell.dart';
import 'package:field_notes/app/shell/shell_content.dart';
import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/app/shell/sidebar_shell.dart';
import 'package:field_notes/app/shell/window_chrome.dart';
import 'package:field_notes/design/feedback/confirm_dialog.dart';
import 'package:field_notes/design/feedback/toast.dart';
import 'package:field_notes/design/motion/motion.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/mood/mood_picker.dart';
import 'package:field_notes/features/mood/mood_picker_sheet.dart';
import 'package:field_notes/features/onboarding/chapters/opening_chapter.dart';
import 'package:field_notes/features/onboarding/onboarding.dart';
import 'package:field_notes/features/reminders/reminder_providers.dart';
import 'package:field_notes/features/today/today_providers.dart';
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
const Duration _growthStep = Duration(milliseconds: 100);
const Duration _toastGone = Duration(seconds: 3);
const int _growthSteps = 60;

const String _dialogTitle = 'Delete this note?';
const String _toastMessage = 'Saved to today.';

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

class _TodayJournal extends FakeJournalRepository {
  final StreamController<Day?> _days = StreamController<Day?>.broadcast();
  Day? _today;

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

final class _PaintOrderContext extends TestRecordingPaintingContext {
  _PaintOrderContext() : super(TestRecordingCanvas());

  final List<RenderObject> painted = <RenderObject>[];

  @override
  void paintChild(RenderObject child, Offset offset) {
    painted.add(child);
    super.paintChild(child, offset);
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

Future<void> _onLayout(_Layout layout, Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = layout.platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

List<Override> _overrides(
  FakeSettingsRepository settings,
  FakeJournalRepository? journal,
) {
  final Set<Object> replaced = <Object>{
    settingsRepositoryProvider,
    reminderSchedulerProvider,
    if (journal != null) journalRepositoryProvider,
  };
  return <Override>[
    for (final Override override in shellOverrides())
      if (!replaced.contains(override.origin)) override,
    settingsRepositoryProvider.overrideWithValue(settings),
    reminderSchedulerProvider.overrideWithValue(RecordingReminderScheduler()),
    if (journal != null) journalRepositoryProvider.overrideWithValue(journal),
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
  FakeSettingsRepository settings, {
  FakeJournalRepository? journal,
}) async {
  tester.view.physicalSize = layout.surface;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: _overrides(settings, journal),
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

FlowerKind? _flower(WidgetTester tester) =>
    tester.widget<PetalDrift>(_petals).flower;

double _petalOpacity(WidgetTester tester) => tester
    .widget<Opacity>(
      find.ancestor(of: _framePetals, matching: find.byType(Opacity)).first,
    )
    .opacity;

OnboardingChapter _chapter(ProviderContainer container) => (container.read(
  onboardingControllerProvider,
) as OnboardingFlowRunning).chapter;

bool _grown(ProviderContainer container) => (container.read(
  onboardingControllerProvider,
) as OnboardingFlowRunning).draft.grown;

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

List<RenderObject> _paintOrder(WidgetTester tester) {
  final _PaintOrderContext context = _PaintOrderContext();
  tester.binding.renderViews.single.paint(context, Offset.zero);
  context.dispose();
  return List<RenderObject>.unmodifiable(context.painted);
}

int _orderOf(
  WidgetTester tester,
  List<RenderObject> painted,
  Finder finder, {
  required String reason,
}) {
  final int order = painted.indexOf(tester.renderObject(finder));
  expect(order, isNonNegative, reason: '$reason is never painted');
  return order;
}

bool _within(RenderObject object, RenderObject root) {
  for (RenderObject? node = object; node != null; node = node.parent) {
    if (identical(node, root)) {
      return true;
    }
  }
  return false;
}

int _lastOrderWithin(
  WidgetTester tester,
  List<RenderObject> painted,
  Finder finder, {
  required String reason,
}) {
  final RenderObject root = tester.renderObject(finder);
  final List<int> orders = <int>[
    for (final (int index, RenderObject object) in painted.indexed)
      if (_within(object, root)) index,
  ];
  expect(orders, isNotEmpty, reason: '$reason is never painted');
  return orders.last;
}

List<Finder> _chromeOf(ShellLayout layout) => switch (layout) {
  ShellLayout.sidebar => <Finder>[
    find.byKey(windowTitleBarKey),
    for (final ShellDestination destination in ShellDestination.primary)
      find.byKey(ValueKey<String>('rail-${destination.name}')),
  ],
  ShellLayout.bottomBar => <Finder>[
    find.text('field notes'),
    find.byKey(const ValueKey<String>('gear-button')),
    find.byKey(const ValueKey<String>('capture-button')),
    for (final ShellDestination destination in ShellDestination.primary)
      find.byKey(ValueKey<String>('tab-${destination.name}')),
  ],
};

Finder _shellOf(ShellLayout layout) => switch (layout) {
  ShellLayout.sidebar => find.byType(SidebarShell),
  ShellLayout.bottomBar => find.byType(BottomBarShell),
};

Finder _calendarItem(ShellLayout layout) => find.byKey(switch (layout) {
  ShellLayout.sidebar => const ValueKey<String>('rail-calendar'),
  ShellLayout.bottomBar => const ValueKey<String>('tab-calendar'),
});

void _expectPaintedAfterTheShell(WidgetTester tester, _Layout layout) {
  final String name = layout.layout.name;
  final List<RenderObject> painted = _paintOrder(tester);
  final int petals = _orderOf(tester, painted, _petals, reason: 'the petals');
  expect(
    _lastOrderWithin(
      tester,
      painted,
      _shellOf(layout.layout),
      reason: '$name shell',
    ),
    lessThan(petals),
    reason: '$name: part of the shell paints over the petals',
  );
  for (final Finder part in _chromeOf(layout.layout)) {
    expect(
      _lastOrderWithin(tester, painted, part, reason: '$name $part'),
      lessThan(petals),
      reason: '$name: $part paints over the petals',
    );
  }
}

void _expectPaintedUnder(
  WidgetTester tester,
  Finder above, {
  required String reason,
}) {
  final List<RenderObject> painted = _paintOrder(tester);
  final int petals = _orderOf(tester, painted, _petals, reason: 'the petals');
  expect(
    _orderOf(tester, painted, above, reason: reason),
    greaterThan(petals),
    reason: '$reason paints under the petals',
  );
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
        Offset.zero & layout.surface,
        reason: reason,
      );
      if (layout.layout == ShellLayout.sidebar) {
        expect(
          tester.getRect(find.byType(ShellContent)),
          isNot(Offset.zero & layout.surface),
          reason: reason,
        );
      }
    }
  }
  await _unmount(tester);
}

Future<void> _growPeony(
  WidgetTester tester,
  ProviderContainer container, {
  required String reason,
}) async {
  for (int step = 0; step < _growthSteps && !_grown(container); step++) {
    expect(_petals, findsNothing, reason: '$reason while the peony grows');
    await tester.pump(_growthStep);
  }
  expect(_grown(container), isTrue, reason: '$reason never grew');
  await tester.pump();
}

Future<void> _expectPetalsOnceThePeonyHasGrownButNotOverTheYear(
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
  expect(_petals, findsNothing, reason: '$name planted');
  await tester.pump(_wholeFade);
  expect(_petals, findsNothing, reason: '$name growing');
  await _growPeony(tester, container, reason: name);

  expect(_framePetals, findsOneWidget, reason: name);
  expect(_petals, findsOneWidget, reason: name);
  expect(_flower(tester), FlowerKind.peony, reason: name);
  expect(_petalOpacity(tester), lessThan(0.05), reason: name);
  await tester.pump(_halfFade);
  expect(_petalOpacity(tester), inExclusiveRange(0, 1), reason: name);
  await tester.pump(_restOfFade);
  expect(_petalOpacity(tester), 1, reason: name);

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

Future<void> _expectPetalsFollowTodaysFlower(
  WidgetTester tester,
  _Layout layout,
) async {
  final String name = layout.layout.name;
  final _TodayJournal journal = _TodayJournal();
  final ProviderContainer container = await _pumpApp(
    tester,
    layout,
    _onboarded(),
    journal: journal,
  );
  final String today = container.read(todayDateProvider);
  expect(find.byType(OnboardingFrame), findsNothing, reason: name);
  expect(_petals, findsOneWidget, reason: name);
  expect(_flower(tester), isNull, reason: '$name with no mood');

  await journal.setMoodForDate(date: today, mood: Mood.calm);
  await _settle(tester);
  expect(_flower(tester), FlowerKind.lavender, reason: '$name calm');

  await journal.setMoodForDate(date: today, mood: Mood.sad);
  await _settle(tester);
  expect(_flower(tester), FlowerKind.bleedingHeart, reason: '$name sad');

  for (final ShellDestination page in ShellDestination.values) {
    container.read(shellNavigationProvider.notifier).select(page);
    await _settle(tester);
    final String reason = '$name ${page.name}';
    if (page == ShellDestination.garden) {
      expect(_petals, findsNothing, reason: reason);
    } else {
      expect(_flower(tester), FlowerKind.bleedingHeart, reason: reason);
    }
  }

  await journal.setMoodForDate(date: today, mood: null);
  await _settle(tester);
  expect(_flower(tester), isNull, reason: '$name cleared');
  await _unmount(tester);
}

Future<void> _expectPetalsBetweenTheShellAndPopUps(
  WidgetTester tester,
  _Layout layout,
) async {
  final String name = layout.layout.name;
  final _TodayJournal journal = _TodayJournal();
  final ProviderContainer container = await _pumpApp(
    tester,
    layout,
    _onboarded(),
    journal: journal,
  );
  await journal.setMoodForDate(
    date: container.read(todayDateProvider),
    mood: Mood.calm,
  );
  await _settle(tester);
  _expectPaintedAfterTheShell(tester, layout);

  final BuildContext page = tester.element(find.byType(ShellContent));
  unawaited(
    showConfirmDialog(
      page,
      title: _dialogTitle,
      message: 'This cannot be undone.',
      confirmLabel: 'Delete',
    ),
  );
  await _settle(tester);
  _expectPaintedUnder(tester, find.text(_dialogTitle), reason: '$name dialog');
  Navigator.of(tester.element(find.text(_dialogTitle))).pop();
  await _settle(tester);

  unawaited(showMoodPicker(page));
  await _settle(tester);
  _expectPaintedUnder(
    tester,
    find.byType(MoodPickerSheet),
    reason: '$name mood picker',
  );
  Navigator.of(tester.element(find.byType(MoodPickerSheet))).pop();
  await _settle(tester);

  showTransientToast(page, _toastMessage);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  _expectPaintedUnder(tester, find.text(_toastMessage), reason: '$name toast');
  await tester.pump(_toastGone);
  await _settle(tester);

  final Finder calendar = _calendarItem(layout.layout);
  final Offset target = tester.getCenter(calendar);
  expect(tester.getRect(_petals).contains(target), isTrue, reason: name);
  await tester.tapAt(target);
  await _settle(tester);
  expect(
    container.read(shellNavigationProvider),
    ShellDestination.calendar,
    reason: '$name tap through the petals',
  );
  expect(_petals, findsOneWidget, reason: name);
  await _unmount(tester);
}

void main() {
  testWidgets(
    'petals drift over every page but the Meadow and through onboarding once '
    'the peony has grown',
    (WidgetTester tester) async {
      for (final _Layout layout in _layouts) {
        await _onLayout(layout, () async {
          await _expectPetalsOnEveryPageButTheMeadow(tester, layout);
          await _expectPetalsOnceThePeonyHasGrownButNotOverTheYear(
            tester,
            layout,
          );
        });
      }
    },
  );

  testWidgets("petals follow today's flower and stop with no mood", (
    WidgetTester tester,
  ) async {
    for (final _Layout layout in _layouts) {
      await _onLayout(layout, () async {
        await _expectPetalsFollowTodaysFlower(tester, layout);
      });
    }
  });

  testWidgets(
    'petals cross the sidebar and bars but stay under dialogs and toasts',
    (WidgetTester tester) async {
      for (final _Layout layout in _layouts) {
        await _onLayout(layout, () async {
          await _expectPetalsBetweenTheShellAndPopUps(tester, layout);
        });
      }
    },
  );
}
