import 'package:field_notes/app/app.dart';
import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:field_notes/domain/mood/mood.dart';
import 'package:field_notes/domain/settings/appearance.dart';
import 'package:field_notes/domain/settings/week_start.dart';
import 'package:field_notes/features/onboarding/chapters/day_chapter.dart';
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
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../app/support/app_shell_harness.dart';
import '../settings/support/fake_settings_repository.dart';
import '../settings/support/recording_reminder_scheduler.dart';

const int _mousePointerId = 47;
const int _mouseDevice = 1;

const Size _sidebarSurface = Size(1280, 800);
const Size _bottomBarSurface = Size(360, 740);
const Offset _parked = Offset(-20, -20);

const Color _ink = Color(0xFF4A3B2E);
const Color _white = Color(0xFFFFFFFF);
const Color _coral = Color(0xFFB8566A);

final int _lightRow = _ink.withValues(alpha: 0.06).toARGB32();
final int _lightPill = _coral.withValues(alpha: 0.08).toARGB32();
final int _dark = _white.withValues(alpha: 0.12).toARGB32();

enum _Role { button, slider }

enum _Shape { circle, rounded }

class _Row {
  const _Row(
    this.name,
    this.control,
    this.label,
    this.fill,
    this.shape, [
    this.radius,
    this.role = _Role.button,
  ]);

  final String name;
  final Finder control;
  final String label;
  final int fill;
  final _Shape shape;
  final double? radius;
  final _Role role;
}

Finder _labelled(String label) => find.byWidgetPredicate(
  (Widget widget) => widget is Pressable && widget.label == label,
);

Finder _around(Finder inner) =>
    find.ancestor(of: inner, matching: find.byType(Pressable)).first;

MouseCursor? _cursor() =>
    RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(_mouseDevice);

Finder _hoverFill(_Row row) => find.descendant(
  of: row.control,
  matchRoot: true,
  matching: find.byWidgetPredicate((Widget widget) {
    if (widget is! DecoratedBox) {
      return false;
    }
    final Decoration decoration = widget.decoration;
    if (decoration is! BoxDecoration ||
        decoration.color?.toARGB32() != row.fill) {
      return false;
    }
    return switch (row.shape) {
      _Shape.circle => decoration.shape == BoxShape.circle,
      _Shape.rounded =>
        decoration.shape == BoxShape.rectangle &&
            decoration.borderRadius == BorderRadius.circular(row.radius!),
    };
  }),
);

Future<void> _expectRows(
  WidgetTester tester,
  TestGesture mouse,
  List<_Row> rows,
) async {
  for (final _Row row in rows) {
    await mouse.moveTo(_parked);
    await tester.pump();
    expect(row.control, findsOneWidget, reason: row.name);
    expect(_hoverFill(row), findsNothing, reason: row.name);

    await mouse.moveTo(tester.getCenter(row.control));
    await tester.pump();

    expect(_cursor(), SystemMouseCursors.click, reason: row.name);
    expect(_hoverFill(row), findsOneWidget, reason: row.name);
    final SemanticsData semantics = tester
        .getSemantics(
          find
              .descendant(
                of: row.control,
                matching: find.byType(Pressable),
                matchRoot: true,
              )
              .first,
        )
        .getSemanticsData();
    expect(semantics.label, row.label, reason: row.name);
    expect(
      row.role == _Role.button
          ? semantics.flagsCollection.isButton
          : semantics.flagsCollection.isSlider,
      isTrue,
      reason: row.name,
    );
  }
  await mouse.moveTo(_parked);
  await tester.pump();
}

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

List<Override> _overrides() {
  final Set<Object> replaced = <Object>{
    settingsRepositoryProvider,
    reminderSchedulerProvider,
  };
  return <Override>[
    for (final Override override in shellOverrides())
      if (!replaced.contains(override.origin)) override,
    settingsRepositoryProvider.overrideWithValue(
      FakeSettingsRepository(storedValues: false),
    ),
    reminderSchedulerProvider.overrideWithValue(RecordingReminderScheduler()),
    onboardingCountryCodeProvider.overrideWithValue('US'),
  ];
}

Future<void> _settle(WidgetTester tester) async {
  for (int frame = 0; frame < 4; frame++) {
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _pumpApp(WidgetTester tester, ShellLayout layout) async {
  tester.view.physicalSize = switch (layout) {
    ShellLayout.sidebar => _sidebarSurface,
    ShellLayout.bottomBar => _bottomBarSurface,
  };
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: _overrides(),
      child: const FieldNotesApp(),
    ),
  );
  await _settle(tester);
  expect(find.byType(OpeningChapter), findsOneWidget);
}

OnboardingController _controller(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(AppShell)))
        .read(onboardingControllerProvider.notifier);

OnboardingChapter _chapter(WidgetTester tester) => (ProviderScope.containerOf(
  tester.element(find.byType(AppShell)),
).read(onboardingControllerProvider) as OnboardingFlowRunning).chapter;

Future<void> _grow(WidgetTester tester) async {
  _controller(tester)
    ..plant()
    ..markGrown();
  await _settle(tester);
}

Future<void> _walkTo(WidgetTester tester, OnboardingChapter target) async {
  final OnboardingController controller = _controller(tester);
  while (_chapter(tester) != target) {
    switch (_chapter(tester)) {
      case OnboardingChapter.opening:
        controller
          ..plant()
          ..markGrown();
      case OnboardingChapter.moment:
        controller.setNote('A first line');
      case OnboardingChapter.month:
        controller.setMonthFill(1);
      case OnboardingChapter.year:
        controller.setYearDay(365, scrubbed: false);
      case OnboardingChapter.day ||
          OnboardingChapter.theme ||
          OnboardingChapter.reminder ||
          OnboardingChapter.week ||
          OnboardingChapter.tour:
        break;
    }
    controller.next();
    await tester.pump();
  }
  await _settle(tester);
}

Future<void> _untilYearShown(WidgetTester tester) async {
  for (
    int frame = 0;
    frame < 6000 && find.byKey(yearSliderKey).evaluate().isEmpty;
    frame++
  ) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
    await tester.pump(const Duration(milliseconds: 1));
  }
  await _settle(tester);
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 3));
}

Future<void> _sidebarRows(WidgetTester tester, TestGesture mouse) async {
  await _onLayout(ShellLayout.sidebar, () async {
    await _pumpApp(tester, ShellLayout.sidebar);
    await _expectRows(tester, mouse, <_Row>[
      _Row(
        'mac opening plant',
        _labelled('Plant your first seed'),
        'Plant your first seed',
        _lightRow,
        _Shape.rounded,
        0,
      ),
    ]);

    await _grow(tester);
    await _expectRows(tester, mouse, <_Row>[
      _Row(
        'mac primary',
        find.byKey(onboardingPrimaryKey),
        'Begin',
        _dark,
        _Shape.rounded,
        14,
      ),
      _Row(
        'mac skip',
        find.byKey(onboardingSkipKey),
        'Skip to setup',
        _dark,
        _Shape.rounded,
        18,
      ),
      _Row(
        'mac progress pill',
        find.byKey(onboardingProgressKey),
        'Chapters',
        _dark,
        _Shape.rounded,
        18,
      ),
    ]);

    await _walkTo(tester, OnboardingChapter.day);
    await _expectRows(tester, mouse, <_Row>[
      _Row(
        'mac back',
        find.byKey(onboardingBackKey),
        'Back',
        _dark,
        _Shape.circle,
      ),
      _Row(
        'mac mood tile',
        find.byKey(dayMoodKey(Mood.happy)),
        'Happy',
        _lightRow,
        _Shape.rounded,
        16,
      ),
    ]);

    await _walkTo(tester, OnboardingChapter.month);
    await _expectRows(tester, mouse, <_Row>[
      _Row(
        'mac month slider',
        _around(find.byKey(monthSliderKey)),
        'Drag to see the weeks ahead',
        _lightRow,
        _Shape.rounded,
        9,
        _Role.slider,
      ),
    ]);

    await _walkTo(tester, OnboardingChapter.year);
    await _untilYearShown(tester);
    await _expectRows(tester, mouse, <_Row>[
      _Row(
        'mac year slider',
        _around(find.byKey(yearSliderKey)),
        'The sample year',
        _dark,
        _Shape.rounded,
        9,
        _Role.slider,
      ),
      _Row(
        'mac year replay',
        _labelled('Replay the year'),
        'Replay the year',
        _dark,
        _Shape.rounded,
        11,
      ),
    ]);

    await _walkTo(tester, OnboardingChapter.theme);
    await _expectRows(tester, mouse, <_Row>[
      _Row(
        'mac theme card',
        find.byKey(themeChoiceKey(Appearance.dark)),
        'Dark, lamplight',
        _lightRow,
        _Shape.rounded,
        16,
      ),
    ]);

    await _walkTo(tester, OnboardingChapter.reminder);
    await _expectRows(tester, mouse, <_Row>[
      _Row(
        'mac reminder choice',
        find.byKey(reminderChoiceKey(ReminderChoice.off)),
        'Off, no nudge',
        _lightRow,
        _Shape.rounded,
        12,
      ),
    ]);

    await _walkTo(tester, OnboardingChapter.week);
    await _expectRows(tester, mouse, <_Row>[
      _Row(
        'mac week choice',
        find.byKey(weekChoiceKey(WeekStart.monday)),
        'Monday',
        _lightRow,
        _Shape.rounded,
        12,
      ),
    ]);

    await _walkTo(tester, OnboardingChapter.tour);
    await _expectRows(tester, mouse, <_Row>[
      _Row(
        'mac tour line',
        find.byKey(tourLineKey(3)),
        '3, Meadow, Your year in bloom. Each flower is a day.',
        _lightRow,
        _Shape.rounded,
        12,
      ),
      _Row(
        'mac start',
        find.byKey(onboardingPrimaryKey),
        'Start journaling',
        _dark,
        _Shape.rounded,
        14,
      ),
    ]);
    await _unmount(tester);
  });
}

Future<void> _phoneRows(WidgetTester tester, TestGesture mouse) async {
  await _onLayout(ShellLayout.bottomBar, () async {
    await _pumpApp(tester, ShellLayout.bottomBar);
    await _expectRows(tester, mouse, <_Row>[
      _Row(
        'phone opening plant',
        _labelled('Plant your first seed'),
        'Plant your first seed',
        _lightRow,
        _Shape.rounded,
        0,
      ),
    ]);

    await _grow(tester);
    await _expectRows(tester, mouse, <_Row>[
      _Row(
        'phone skip',
        find.byKey(onboardingSkipKey),
        'Skip',
        _lightPill,
        _Shape.rounded,
        22,
      ),
    ]);

    await _walkTo(tester, OnboardingChapter.day);
    await _expectRows(tester, mouse, <_Row>[
      _Row(
        'phone back on soil',
        find.byKey(onboardingBackKey),
        'Back',
        _dark,
        _Shape.circle,
      ),
      _Row(
        'phone mood tile',
        find.byKey(dayMoodKey(Mood.happy)),
        'Happy',
        _lightRow,
        _Shape.rounded,
        14,
      ),
      _Row(
        'phone progress mark',
        _labelled('Opening'),
        'Opening',
        _dark,
        _Shape.rounded,
        16,
      ),
    ]);

    await _walkTo(tester, OnboardingChapter.moment);
    _controller(tester)
      ..setNote('A first line')
      ..openOtherWays();
    await _settle(tester);
    await _expectRows(tester, mouse, <_Row>[
      _Row(
        'phone other ways',
        find.byKey(otherWaysSpeakKey),
        'Say it out loud',
        _dark,
        _Shape.rounded,
        22,
      ),
    ]);
    _controller(tester).closeOtherWays();
    await _settle(tester);

    await _walkTo(tester, OnboardingChapter.month);
    await _expectRows(tester, mouse, <_Row>[
      _Row(
        'phone month slider',
        _around(find.byKey(monthSliderKey)),
        'drag to see the weeks ahead',
        _lightRow,
        _Shape.rounded,
        9,
        _Role.slider,
      ),
      _Row(
        'phone back',
        find.byKey(onboardingBackKey),
        'Back',
        _lightRow,
        _Shape.circle,
      ),
    ]);

    await _walkTo(tester, OnboardingChapter.year);
    await _untilYearShown(tester);
    await _expectRows(tester, mouse, <_Row>[
      _Row(
        'phone year slider',
        _around(find.byKey(yearSliderKey)),
        'The sample year',
        _dark,
        _Shape.rounded,
        9,
        _Role.slider,
      ),
      _Row(
        'phone year replay',
        _labelled('Replay the year'),
        'Replay the year',
        _dark,
        _Shape.circle,
      ),
      _Row(
        'phone skip on the meadow',
        find.byKey(onboardingSkipKey),
        'Skip',
        _dark,
        _Shape.rounded,
        22,
      ),
    ]);

    await _walkTo(tester, OnboardingChapter.theme);
    await _expectRows(tester, mouse, <_Row>[
      _Row(
        'phone theme row',
        find.byKey(themeChoiceKey(Appearance.dark)),
        'Dark, Lamplight, easy at night',
        _lightRow,
        _Shape.rounded,
        0,
      ),
    ]);

    await _walkTo(tester, OnboardingChapter.reminder);
    await _expectRows(tester, mouse, <_Row>[
      _Row(
        'phone reminder row',
        find.byKey(reminderChoiceKey(ReminderChoice.off)),
        "No reminder, You'll open it when you want",
        _lightRow,
        _Shape.rounded,
        0,
      ),
    ]);

    await _walkTo(tester, OnboardingChapter.week);
    await _expectRows(tester, mouse, <_Row>[
      _Row(
        'phone week row',
        find.byKey(weekChoiceKey(WeekStart.monday)),
        'Monday, Most of Europe',
        _lightRow,
        _Shape.rounded,
        0,
      ),
    ]);

    await _walkTo(tester, OnboardingChapter.tour);
    await _expectRows(tester, mouse, <_Row>[
      _Row(
        'phone tour line',
        find.byKey(tourLineKey(1)),
        'Today, Your day, its mood and its logs.',
        _lightRow,
        _Shape.rounded,
        14,
      ),
    ]);
    await _unmount(tester);
  });
}

Future<void> _textButtonRows(WidgetTester tester, TestGesture mouse) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: fieldNotesTheme(platform: TargetPlatform.macOS),
      home: Scaffold(
        body: Center(
          child: OnboardingTextButton(
            label: 'Not now',
            semanticLabel: 'Not now, set it later',
            onPressed: () {},
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await _expectRows(tester, mouse, <_Row>[
    _Row(
      'text button',
      find.byType(OnboardingTextButton),
      'Not now, set it later',
      _lightRow,
      _Shape.rounded,
      6,
    ),
  ]);
  await _unmount(tester);
}

void main() {
  testWidgets('every onboarding control shows the click cursor and hover', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final TestGesture mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      pointer: _mousePointerId,
    );
    await mouse.addPointer(location: _parked);
    addTearDown(mouse.removePointer);

    await _sidebarRows(tester, mouse);
    await _phoneRows(tester, mouse);
    await _textButtonRows(tester, mouse);
    semantics.dispose();
  });
}
