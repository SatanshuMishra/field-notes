import 'package:field_notes/app/app.dart';
import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/icons/nav_icons.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart';
import 'package:field_notes/features/onboarding/chapters/opening_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/tour_chapter.dart';
import 'package:field_notes/features/onboarding/onboarding.dart';
import 'package:field_notes/features/reminders/reminder_providers.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../app/support/app_shell_harness.dart';
import '../../settings/support/fake_settings_repository.dart';
import '../../settings/support/recording_reminder_scheduler.dart';

const Size _sidebarSurface = Size(1280, 800);
const Size _bottomBarSurface = Size(360, 740);

const String _kicker = 'one last thing';
const String _title = "Here's where everything lives.";

typedef _Place = ({String title, String line});

const List<_Place> _sidebarPlaces = <_Place>[
  (
    title: 'Today',
    line:
        'Your day: its mood, its notes, voice and video. New logs start here.',
  ),
  (
    title: 'Calendar',
    line: "Every day you've kept. Tap one to revisit it, or add to it.",
  ),
  (title: 'Meadow', line: 'Your year in bloom. Each flower is a day.'),
  (title: 'Search', line: 'Find any memory by a word, a mood or a date.'),
  (
    title: 'Settings',
    line: 'Theme, reminders and your week. Change them anytime.',
  ),
];

const List<_Place> _bottomBarPlaces = <_Place>[
  (title: 'Today', line: 'Your day, its mood and its logs.'),
  (title: 'Calendar', line: "Every day you've kept."),
  (title: 'New log', line: 'Write, speak, film or add a photo.'),
  (title: 'Meadow', line: 'Your year in bloom.'),
  (title: 'Search', line: 'Find any memory.'),
  (title: 'Settings', line: 'The gear on Today: theme, reminders, week.'),
];

const List<String> _sidebarNavLabels = <String>[
  'Today',
  'Calendar',
  'Meadow',
  'Search',
];

const Map<int, NavGlyph> _sidebarGlyphs = <int, NavGlyph>{
  1: NavGlyph.home,
  2: NavGlyph.calendar,
  3: NavGlyph.garden,
  4: NavGlyph.search,
};

const Map<int, NavGlyph> _bottomBarGlyphs = <int, NavGlyph>{
  1: NavGlyph.home,
  2: NavGlyph.calendar,
  4: NavGlyph.garden,
  5: NavGlyph.search,
};

List<_Place> _placesFor(ShellLayout layout) => switch (layout) {
  ShellLayout.sidebar => _sidebarPlaces,
  ShellLayout.bottomBar => _bottomBarPlaces,
};

Map<int, NavGlyph> _glyphsFor(ShellLayout layout) => switch (layout) {
  ShellLayout.sidebar => _sidebarGlyphs,
  ShellLayout.bottomBar => _bottomBarGlyphs,
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

void _sizeFor(WidgetTester tester, ShellLayout layout) {
  tester.view.physicalSize = switch (layout) {
    ShellLayout.sidebar => _sidebarSurface,
    ShellLayout.bottomBar => _bottomBarSurface,
  };
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
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
  ];
}

Future<void> _settle(WidgetTester tester) async {
  for (int frame = 0; frame < 4; frame++) {
    await tester.pump();
  }
  await tester.pump(const Duration(seconds: 1));
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(AppShell)));

OnboardingController _controller(WidgetTester tester) =>
    _container(tester).read(onboardingControllerProvider.notifier);

OnboardingChapter _chapter(WidgetTester tester) => (_container(
  tester,
).read(onboardingControllerProvider) as OnboardingFlowRunning).chapter;

Future<void> _openTour(WidgetTester tester, ShellLayout layout) async {
  _sizeFor(tester, layout);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: _overrides(FakeSettingsRepository(storedValues: false)),
      child: const FieldNotesApp(),
    ),
  );
  await _settle(tester);
  expect(find.byType(OpeningChapter), findsOneWidget);
  final OnboardingController controller = _controller(tester);
  controller.skipToSetup();
  while (_chapter(tester) != OnboardingChapter.tour) {
    controller.next();
  }
  await _settle(tester);
  expect(find.byType(TourChapter), findsOneWidget);
}

Future<void> _replayTour(WidgetTester tester) async {
  await tester.tap(find.byKey(onboardingPrimaryKey));
  await _settle(tester);
  expect(find.byType(OnboardingFrame), findsNothing);
  _controller(tester).showMap();
  await _settle(tester);
  expect(
    _container(tester).read(onboardingControllerProvider),
    const OnboardingFlowMap(),
  );
  expect(find.byType(TourChapter), findsOneWidget);
}

Future<void> _pumpStill(WidgetTester tester, ShellLayout layout) async {
  _sizeFor(tester, layout);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: shellOverrides(),
      child: MaterialApp(
        theme: fieldNotesTheme(platform: defaultTargetPlatform),
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Material(child: TourChapter(layout: layout)),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}

Finder _line(int number) => find.byKey(tourLineKey(number));

Finder _lineBadge(int number) =>
    find.descendant(of: _line(number), matching: find.byType(TourBadge));

Finder _badge(int number) => find.byKey(tourBadgeKey(number));

Finder _target(int number) => find.byKey(tourTargetKey(number));

Iterable<double> _opacitiesAbove(WidgetTester tester, Finder finder) => tester
    .widgetList<Opacity>(
      find.ancestor(of: finder, matching: find.byType(Opacity)),
    )
    .map((Opacity opacity) => opacity.opacity);

void _expectPlaces(WidgetTester tester, ShellLayout layout) {
  final List<_Place> places = _placesFor(layout);
  final Map<int, NavGlyph> glyphs = _glyphsFor(layout);
  expect(find.text(_kicker), findsOneWidget);
  expect(find.text(_title), findsOneWidget);
  for (final (int index, _Place place) in places.indexed) {
    final int number = index + 1;
    expect(_line(number), findsOneWidget);
    for (final String text in <String>['$number', place.title, place.line]) {
      expect(
        find.descendant(of: _line(number), matching: find.text(text)),
        findsOneWidget,
      );
    }
    expect(
      find.descendant(of: _badge(number), matching: find.text('$number')),
      findsOneWidget,
    );
    expect(_target(number), findsOneWidget);
    final Finder icon = find.descendant(
      of: _target(number),
      matching: find.byType(NavIcon),
    );
    final NavGlyph? glyph = glyphs[number];
    if (glyph != null) {
      expect(tester.widget<NavIcon>(icon).glyph, glyph);
    } else {
      expect(icon, findsNothing);
    }
  }
  final int gear = places.length;
  expect(
    tester
        .widget<IconStickerGlyphIcon>(
          find.descendant(
            of: _target(gear),
            matching: find.byType(IconStickerGlyphIcon),
          ),
        )
        .glyph,
    IconStickerGlyph.gear,
  );
  if (layout == ShellLayout.sidebar) {
    for (final (int index, String label) in _sidebarNavLabels.indexed) {
      expect(
        find.descendant(of: _target(index + 1), matching: find.text(label)),
        findsOneWidget,
      );
    }
  }
  expect(_line(places.length + 1), findsNothing);
  expect(_badge(places.length + 1), findsNothing);
  expect(_target(places.length + 1), findsNothing);
}

void _expectHighlighted(
  WidgetTester tester,
  ShellLayout layout,
  int? highlighted,
) {
  for (final (int index, _Place place) in _placesFor(layout).indexed) {
    final int number = index + 1;
    final bool on = number == highlighted;
    expect(tester.widget<TourBadge>(_lineBadge(number)).highlighted, on);
    expect(tester.widget<TourBadge>(_badge(number)).highlighted, on);
    expect(tester.widget<MapPlaceHighlight>(_target(number)).highlighted, on);
    expect(
      tester.getSemantics(_line(number)),
      isSemantics(
        label: '$number, ${place.title}, ${place.line}',
        isFocusable: true,
        isSelected: on,
      ),
    );
  }
}

Future<void> _hover(TestGesture mouse, WidgetTester tester, int number) async {
  await mouse.moveTo(tester.getCenter(_line(number)));
  await tester.pump();
  await tester.pump();
}

Future<void> _focus(WidgetTester tester, ShellLayout layout, int number) async {
  final String title = _placesFor(layout)[number - 1].title;
  Focus.of(
    tester.element(
      find.descendant(of: _line(number), matching: find.text(title)),
    ),
  ).requestFocus();
  await tester.pump();
  await tester.pump();
}

Future<void> _expectHoverAndFocus(
  WidgetTester tester,
  ShellLayout layout,
) async {
  _expectHighlighted(tester, layout, null);

  final TestGesture mouse = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
  );
  await mouse.addPointer(location: Offset.zero);
  await _hover(mouse, tester, 3);
  _expectHighlighted(tester, layout, 3);
  await _hover(mouse, tester, 1);
  _expectHighlighted(tester, layout, 1);
  await mouse.removePointer();
  await tester.pump();

  await _focus(tester, layout, 3);
  _expectHighlighted(tester, layout, 3);
  await _focus(tester, layout, 2);
  _expectHighlighted(tester, layout, 2);
}

void main() {
  testWidgets(
    'the map lists every place with its line and highlights it on hover or focus',
    (WidgetTester tester) async {
      for (final ShellLayout layout in ShellLayout.values) {
        await _onLayout(layout, () async {
          await _openTour(tester, layout);
          _expectPlaces(tester, layout);
          await _expectHoverAndFocus(tester, layout);

          await _replayTour(tester);
          _expectPlaces(tester, layout);
          await _expectHoverAndFocus(tester, layout);
          await _unmount(tester);
        });
      }
    },
  );

  testWidgets('the map skips every entrance with reduce motion', (
    WidgetTester tester,
  ) async {
    for (final ShellLayout layout in ShellLayout.values) {
      await _onLayout(layout, () async {
        await _pumpStill(tester, layout);

        expect(tester.hasRunningAnimations, isFalse);
        expect(_opacitiesAbove(tester, find.text(_title)), everyElement(1));
        for (int number = 1; number <= _placesFor(layout).length; number++) {
          expect(_opacitiesAbove(tester, _line(number)), everyElement(1));
          expect(_opacitiesAbove(tester, _target(number)), everyElement(1));
        }
        _expectPlaces(tester, layout);
        _expectHighlighted(tester, layout, null);
        await _unmount(tester);
      });
    }
  });
}
