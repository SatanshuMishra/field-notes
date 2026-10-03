import 'package:field_notes/app/app.dart';
import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/shell/phone_bottom_bar.dart';
import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/glass/glass.dart';
import 'package:field_notes/design/icons/flame_icon.dart';
import 'package:field_notes/design/icons/nav_icons.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart';
import 'package:field_notes/features/onboarding/chapters/opening_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/tour_chapter.dart';
import 'package:field_notes/features/onboarding/onboarding.dart';
import 'package:field_notes/features/reminders/reminder_providers.dart';
import 'package:field_notes/features/streak/streak.dart';
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
const Size _bottomBarSurface = Size(384, 832);
const double _statusBar = 34;
const double _gestureBar = 24;

const String _kicker = 'one last thing';
const String _title = "Here's where everything lives.";
const String _subtitle = 'Tap a row to see it in the app.';

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
    title: 'Streak',
    line: 'Days in a row, in the sidebar. Miss one and it waits for you.',
  ),
  (
    title: 'Settings',
    line: 'The gear at the foot of the sidebar: theme, reminders, your week.',
  ),
];

const List<_Place> _bottomBarPlaces = <_Place>[
  (title: 'Today', line: 'Your day, its mood and its logs.'),
  (title: 'Calendar', line: 'A month of flowers. Swipe to change month.'),
  (title: 'New log', line: 'Write, speak, film or add a photo.'),
  (title: 'Meadow', line: 'Your year in bloom, full screen.'),
  (title: 'Search', line: 'The field sits at the bottom, by your thumb.'),
  (title: 'Streak', line: 'Days in a row, top right of every page.'),
  (title: 'Settings', line: 'The gear beside it: theme, reminders, week.'),
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
  3: NavGlyph.plus,
  4: NavGlyph.garden,
  5: NavGlyph.search,
};

const Map<int, ShellDestination> _bottomBarTabs = <int, ShellDestination>{
  1: ShellDestination.today,
  2: ShellDestination.calendar,
  4: ShellDestination.garden,
  5: ShellDestination.search,
};

const int _sidebarStreak = 5;
const int _sidebarGear = 6;
const int _bottomBarAdd = 3;
const int _bottomBarStreak = 6;
const int _bottomBarGear = 7;
const int _streakCount = 4;

const double _phoneBarHeight = 64;
const double _barSide = 12;
const double _headerRightInset = 7.5;
const double _pillHeight = 30;
const double _gearExtent = 36;
const double _captureExtent = 46;
const double _captureRing = 4;
const double _ringSpread = 4;
const Color _ring = Color.fromRGBO(199, 106, 84, 0.25);
const Color _streakFlame = Color(0xFFE0863C);

List<_Place> _placesFor(ShellLayout layout) => switch (layout) {
  ShellLayout.sidebar => _sidebarPlaces,
  ShellLayout.bottomBar => _bottomBarPlaces,
};

int? _firstHighlight(ShellLayout layout) => switch (layout) {
  ShellLayout.sidebar => null,
  ShellLayout.bottomBar => 1,
};

String _labelFor(ShellLayout layout, int number, _Place place) =>
    switch (layout) {
      ShellLayout.sidebar => '$number, ${place.title}, ${place.line}',
      ShellLayout.bottomBar => '${place.title}, ${place.line}',
    };

int _streakFor(ShellLayout layout) => switch (layout) {
  ShellLayout.sidebar => _sidebarStreak,
  ShellLayout.bottomBar => _bottomBarStreak,
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
  tester.view.devicePixelRatio = 1;
  switch (layout) {
    case ShellLayout.sidebar:
      tester.view.physicalSize = _sidebarSurface;
      tester.view.resetPadding();
      tester.view.resetViewPadding();
    case ShellLayout.bottomBar:
      tester.view.physicalSize = _bottomBarSurface;
      tester.view.padding = const FakeViewPadding(
        top: _statusBar,
        bottom: _gestureBar,
      );
      tester.view.viewPadding = const FakeViewPadding(
        top: _statusBar,
        bottom: _gestureBar,
      );
  }
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

Future<void> _settleHighlight(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
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
    await tester.pump();
  }
  await _settle(tester);
  expect(find.byType(TourChapter), findsOneWidget);
}

Future<void> _replayTour(WidgetTester tester, ShellLayout layout) async {
  switch (layout) {
    case ShellLayout.sidebar:
      await tester.tap(find.byKey(onboardingPrimaryKey));
    case ShellLayout.bottomBar:
      await tester.flingFrom(
        tester.getCenter(_line(4)),
        const Offset(-300, 0),
        800,
      );
  }
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

Future<void> _pumpStill(
  WidgetTester tester,
  ShellLayout layout, {
  Brightness brightness = Brightness.light,
}) async {
  _sizeFor(tester, layout);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: shellOverrides(),
      child: MaterialApp(
        theme: fieldNotesTheme(
          platform: defaultTargetPlatform,
          brightness: brightness,
        ),
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

final Finder _tour = find.byType(TourChapter);

Finder _inside(Finder of, Finder matching) =>
    find.descendant(of: of, matching: matching);

Finder _inTour(Finder matching) => _inside(_tour, matching);

Finder _line(int number) => find.byKey(tourLineKey(number));

Finder _lineBadge(int number) => _inside(_line(number), find.byType(TourBadge));

Finder _badge(int number) => find.byKey(tourBadgeKey(number));

Finder _target(int number) => find.byKey(tourTargetKey(number));

Finder _pillIn(int target) => _inside(_target(target), find.byType(StreakPill));

Finder get _miniatureBar => _inTour(find.byType(PhoneBottomBar));

Finder _barIcon(NavGlyph glyph) => _inside(
  _miniatureBar,
  find.byWidgetPredicate(
    (Widget widget) => widget is NavIcon && widget.glyph == glyph,
  ),
);

Finder _circleIn(Finder of) => _inside(
  of,
  find.byWidgetPredicate(
    (Widget widget) =>
        widget is DecoratedBox &&
        widget.decoration is BoxDecoration &&
        (widget.decoration as BoxDecoration).shape == BoxShape.circle,
  ),
);

BoxDecoration _decorationOf(WidgetTester tester, Finder box) =>
    tester.widget<DecoratedBox>(box).decoration as BoxDecoration;

Iterable<double> _opacitiesAbove(WidgetTester tester, Finder finder) => tester
    .widgetList<Opacity>(
      find.ancestor(of: finder, matching: find.byType(Opacity)),
    )
    .map((Opacity opacity) => opacity.opacity);

void _expectPlaces(WidgetTester tester, ShellLayout layout) {
  final List<_Place> places = _placesFor(layout);
  final bool sidebar = layout == ShellLayout.sidebar;
  expect(_inTour(find.text(_kicker)), findsOneWidget);
  expect(_inTour(find.text(_title)), findsOneWidget);
  expect(
    _inTour(find.text(_subtitle)),
    sidebar ? findsNothing : findsOneWidget,
  );
  for (final (int index, _Place place) in places.indexed) {
    final int number = index + 1;
    expect(_line(number), findsOneWidget);
    expect(_target(number), findsOneWidget);
    for (final String text in <String>[place.title, place.line]) {
      expect(_inside(_line(number), find.text(text)), findsOneWidget);
    }
    if (sidebar) {
      expect(_inside(_line(number), find.text('$number')), findsOneWidget);
      expect(_inside(_badge(number), find.text('$number')), findsOneWidget);
    }
  }
  expect(_line(places.length + 1), findsNothing);
  expect(_target(places.length + 1), findsNothing);
  expect(_badge(places.length + 1), findsNothing);
  final StreakPill pill = tester.widget<StreakPill>(
    _pillIn(_streakFor(layout)),
  );
  expect(pill.count, _streakCount);
  expect(pill.numberOnly, !sidebar);
  if (sidebar) {
    expect(pill.form, StreakPillForm.sidebar);
    expect(
      _inside(_pillIn(_sidebarStreak), find.text('4 days')),
      findsOneWidget,
    );
    for (final (int index, String label) in _sidebarNavLabels.indexed) {
      final int number = index + 1;
      expect(_inside(_target(number), find.text(label)), findsOneWidget);
      expect(
        tester
            .widget<NavIcon>(_inside(_target(number), find.byType(NavIcon)))
            .glyph,
        _sidebarGlyphs[number],
      );
    }
    expect(
      tester
          .widget<IconStickerGlyphIcon>(
            _inside(_target(_sidebarGear), find.byType(IconStickerGlyphIcon)),
          )
          .glyph,
      IconStickerGlyph.gear,
    );
    return;
  }
  expect(pill.form, StreakPillForm.header);
  expect(_inside(_pillIn(_bottomBarStreak), find.text('4')), findsOneWidget);
  expect(
    tester
        .widget<Icon>(_inside(_target(_bottomBarGear), find.byType(Icon)))
        .icon,
    Icons.settings_outlined,
  );
  expect(_inTour(find.byType(TourBadge)), findsNothing);
  expect(_miniatureBar, findsOneWidget);
  for (final MapEntry<int, NavGlyph> entry in _bottomBarGlyphs.entries) {
    expect(
      tester
          .getRect(_target(entry.key))
          .contains(tester.getCenter(_barIcon(entry.value))),
      isTrue,
      reason: 'target ${entry.key} holds the ${entry.value.name} item',
    );
    expect(
      tester
          .widget<NavIcon>(_inside(_line(entry.key), find.byType(NavIcon)))
          .glyph,
      entry.value,
      reason: 'row ${entry.key} icon',
    );
  }
  expect(
    _inside(_line(_bottomBarStreak), find.byType(FlameIcon)),
    findsOneWidget,
  );
  expect(
    tester.widget<Icon>(_inside(_line(_bottomBarGear), find.byType(Icon))).icon,
    Icons.settings_outlined,
  );
}

void _expectHighlighted(
  WidgetTester tester,
  ShellLayout layout,
  int? highlighted,
) {
  for (final (int index, _Place place) in _placesFor(layout).indexed) {
    final int number = index + 1;
    final bool on = number == highlighted;
    expect(tester.widget<MapPlaceHighlight>(_target(number)).highlighted, on);
    if (layout == ShellLayout.sidebar) {
      expect(tester.widget<TourBadge>(_lineBadge(number)).highlighted, on);
      expect(tester.widget<TourBadge>(_badge(number)).highlighted, on);
    }
    expect(
      tester.getSemantics(_line(number)),
      isSemantics(
        label: _labelFor(layout, number, place),
        isFocusable: true,
        isSelected: on,
      ),
    );
  }
  expect(
    tester.widget<StreakPill>(_pillIn(_streakFor(layout))).highlighted,
    highlighted == _streakFor(layout),
  );
  if (layout == ShellLayout.bottomBar) {
    expect(
      tester.widget<PhoneBottomBar>(_miniatureBar).selected,
      _bottomBarTabs[highlighted],
    );
  }
}

void _expectTabPill(WidgetTester tester, ShellDestination? selected) {
  final int pill = GlassTone.paper
      .pillFor(Theme.of(tester.element(_miniatureBar)).brightness)
      .toARGB32();
  final Finder pills = _inside(
    _miniatureBar,
    find.byWidgetPredicate(
      (Widget widget) =>
          widget is DecoratedBox &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).color?.toARGB32() == pill,
    ),
  );
  if (selected == null) {
    expect(pills, findsNothing);
    return;
  }
  expect(pills, findsOneWidget);
  expect(
    tester.widget<NavIcon>(_inside(pills, find.byType(NavIcon))).glyph,
    selected.glyph,
  );
}

void _expectCaptureRing(WidgetTester tester, {required bool on}) {
  final Finder ring = _inside(
    _target(_bottomBarAdd),
    find.byType(DecoratedBox),
  );
  final Border border = _decorationOf(tester, ring).border! as Border;
  expect(border.top.width, _captureRing);
  expect(
    border.top.color.toARGB32(),
    on ? Palette.coral30.toARGB32() : Palette.coral30.withAlpha(0).toARGB32(),
  );
  final Rect capture = tester.getRect(_circleIn(_miniatureBar));
  final Rect around = tester.getRect(ring);
  expect(capture.width, moreOrLessEquals(_captureExtent, epsilon: 0.01));
  expect(
    around.width,
    moreOrLessEquals(_captureExtent + 2 * _captureRing, epsilon: 0.01),
  );
  expect(around.center.dx, moreOrLessEquals(capture.center.dx, epsilon: 0.01));
  expect(around.center.dy, moreOrLessEquals(capture.center.dy, epsilon: 0.01));
}

void _expectStreakRing(WidgetTester tester, int target, {required bool on}) {
  final BoxDecoration face = _decorationOf(
    tester,
    _inside(_pillIn(target), find.byType(DecoratedBox)).first,
  );
  expect(
    (face.boxShadow ?? const <BoxShadow>[]).where(
      (BoxShadow shadow) =>
          shadow.spreadRadius == _ringSpread &&
          shadow.color.toARGB32() == _ring.toARGB32(),
    ),
    hasLength(on ? 1 : 0),
  );
  expect(face.color!.toARGB32() == Palette.coral.toARGB32(), on);
}

void _expectPhoneGear(WidgetTester tester, {required bool on}) {
  final FieldNotesColors colors = FieldNotesColors.of(
    tester.element(_target(_bottomBarGear)),
  );
  final BoxDecoration face = _decorationOf(
    tester,
    _inside(_target(_bottomBarGear), find.byType(DecoratedBox)).first,
  );
  expect(
    face.color!.toARGB32(),
    on ? Palette.coral.toARGB32() : Palette.coral.withAlpha(0).toARGB32(),
  );
  final BoxShadow ring = face.boxShadow!.single;
  expect(ring.spreadRadius, _ringSpread);
  expect(
    ring.color.toARGB32(),
    on ? _ring.toARGB32() : _ring.withAlpha(0).toARGB32(),
  );
  expect(
    tester
        .widget<Icon>(_inside(_target(_bottomBarGear), find.byType(Icon)))
        .color!
        .toARGB32(),
    on ? Palette.onAccent.toARGB32() : colors.ink.toARGB32(),
  );
}

void _expectRowIcon(WidgetTester tester, int number, {required bool on}) {
  final FieldNotesColors colors = FieldNotesColors.of(
    tester.element(_line(number)),
  );
  expect(
    _decorationOf(tester, _circleIn(_line(number))).color!.toARGB32(),
    on ? Palette.coral.toARGB32() : colors.cardWarm.toARGB32(),
    reason: 'row $number icon box',
  );
  if (number == _bottomBarStreak) {
    expect(
      tester
          .widget<FlameIcon>(_inside(_line(number), find.byType(FlameIcon)))
          .color
          .toARGB32(),
      on ? Palette.onAccent.toARGB32() : _streakFlame.toARGB32(),
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
  _expectHighlighted(tester, layout, _firstHighlight(layout));

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

          await _replayTour(tester, layout);
          _expectPlaces(tester, layout);
          await _expectHoverAndFocus(tester, layout);
          await _unmount(tester);
        });
      }
    },
  );

  testWidgets(
    "the phone map's replicas are the real bar, pill and gear and light each place",
    (WidgetTester tester) async {
      await _onLayout(ShellLayout.bottomBar, () async {
        await _openTour(tester, ShellLayout.bottomBar);

        final PhoneBottomBar bar = tester.widget<PhoneBottomBar>(_miniatureBar);
        expect(bar.destinations, ShellDestination.primary);
        expect(bar.onSelect, isNull);
        expect(bar.onCapture, isNull);
        expect(bar.overScene, isFalse);
        expect(
          tester
              .widget<GlassSurface>(
                _inside(_miniatureBar, find.byType(GlassSurface)),
              )
              .tone,
          GlassTone.paper,
        );
        expect(
          _inside(_miniatureBar, find.byType(GestureDetector)),
          findsNothing,
        );
        expect(
          _inside(
            _miniatureBar,
            find.byKey(const ValueKey<String>('capture-button')),
          ),
          findsNothing,
        );

        final Rect tour = tester.getRect(_tour);
        final Rect barRect = tester.getRect(_miniatureBar);
        final Rect firstLine = tester.getRect(_line(1));
        final Rect lastLine = tester.getRect(_line(_bottomBarPlaces.length));
        expect(barRect.left - tour.left, moreOrLessEquals(_barSide));
        expect(tour.right - barRect.right, moreOrLessEquals(_barSide));
        expect(barRect.left, moreOrLessEquals(firstLine.left, epsilon: 0.01));
        expect(barRect.right, moreOrLessEquals(firstLine.right, epsilon: 0.01));
        expect(
          barRect.height,
          moreOrLessEquals(_phoneBarHeight, epsilon: 0.01),
        );
        expect(barRect.top, greaterThan(lastLine.bottom));
        expect(
          barRect.bottom,
          lessThanOrEqualTo(
            tester.getRect(find.byKey(onboardingControlBarKey)).top,
          ),
        );
        final double column = barRect.width / 5;
        for (final MapEntry<int, NavGlyph> entry in _bottomBarGlyphs.entries) {
          expect(
            tester.getCenter(_barIcon(entry.value)).dx,
            moreOrLessEquals(
              barRect.left + column * (entry.key - 0.5),
              epsilon: 0.01,
            ),
            reason: 'bar item ${entry.key}',
          );
        }

        final Rect pill = tester.getRect(_pillIn(_bottomBarStreak));
        final Rect gear = tester.getRect(_target(_bottomBarGear));
        expect(pill.height, moreOrLessEquals(_pillHeight, epsilon: 0.01));
        expect(gear.width, moreOrLessEquals(_gearExtent, epsilon: 0.01));
        expect(gear.height, moreOrLessEquals(_gearExtent, epsilon: 0.01));
        expect(gear.left, greaterThan(pill.right));
        expect(
          gear.right,
          moreOrLessEquals(firstLine.right - _headerRightInset, epsilon: 0.01),
        );
        expect(pill.center.dy, moreOrLessEquals(gear.center.dy, epsilon: 0.01));
        expect(gear.bottom, lessThan(firstLine.top));

        for (int number = 1; number <= _bottomBarPlaces.length; number++) {
          await tester.tap(_line(number));
          await _settleHighlight(tester);
          _expectHighlighted(tester, ShellLayout.bottomBar, number);
          _expectTabPill(tester, _bottomBarTabs[number]);
          _expectCaptureRing(tester, on: number == _bottomBarAdd);
          _expectStreakRing(
            tester,
            _bottomBarStreak,
            on: number == _bottomBarStreak,
          );
          _expectPhoneGear(tester, on: number == _bottomBarGear);
          for (int row = 1; row <= _bottomBarPlaces.length; row++) {
            _expectRowIcon(tester, row, on: row == number);
          }
        }

        await _focus(tester, ShellLayout.bottomBar, 2);
        await _settleHighlight(tester);
        _expectTabPill(tester, ShellDestination.calendar);
        await _focus(tester, ShellLayout.bottomBar, 5);
        await _settleHighlight(tester);
        _expectTabPill(tester, ShellDestination.search);
        await _unmount(tester);
      });
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
        _expectHighlighted(tester, layout, _firstHighlight(layout));
        await _unmount(tester);
      });
    }
  });

  testWidgets('the map reads its ink and paper from the dark theme', (
    WidgetTester tester,
  ) async {
    const FieldNotesColors dark = FieldNotesColors.dark;
    for (final ShellLayout layout in ShellLayout.values) {
      await _onLayout(layout, () async {
        await _pumpStill(tester, layout, brightness: Brightness.dark);

        expect(
          tester.widget<Text>(find.text(_title)).style!.color!.toARGB32(),
          dark.ink.toARGB32(),
        );
        final _Place first = _placesFor(layout).first;
        expect(
          tester
              .widget<Text>(_inside(_line(1), find.text(first.line)))
              .style!
              .color!
              .toARGB32(),
          dark.inkSoft.toARGB32(),
        );
        if (layout == ShellLayout.bottomBar) {
          expect(
            tester.widget<Text>(find.text(_subtitle)).style!.color!.toARGB32(),
            dark.mutedDeep.toARGB32(),
          );
          final BoxDecoration header = _decorationOf(
            tester,
            find
                .ancestor(
                  of: _target(_bottomBarStreak),
                  matching: find.byType(DecoratedBox),
                )
                .first,
          );
          expect(header.color!.toARGB32(), dark.panelTop.toARGB32());
          _expectRowIcon(tester, 1, on: true);
          _expectRowIcon(tester, 2, on: false);
        }
        await _unmount(tester);
      });
    }
  });
}
