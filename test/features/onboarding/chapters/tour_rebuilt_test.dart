import 'package:field_notes/app/app.dart';
import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/shell/phone_bottom_bar.dart';
import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/design/glass/glass.dart';
import 'package:field_notes/design/icons/nav_icons.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart';
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

const Size _phone = Size(384, 832);
const Size _mac = Size(1280, 800);
const double _statusBar = 34;
const double _gestureBar = 24;

const String _kicker = 'one last thing';
const String _title = "Here's where everything lives.";
const String _subtitle = 'Tap a row to see it in the app.';
const String _headerTitle = 'Today';

typedef _Place = ({String title, String line});

const List<_Place> _phonePlaces = <_Place>[
  (title: 'Today', line: 'Your day, its mood and its logs.'),
  (title: 'Calendar', line: 'A month of flowers. Swipe to change month.'),
  (title: 'New log', line: 'Write, speak, film or add a photo.'),
  (title: 'Meadow', line: 'Your year in bloom, full screen.'),
  (title: 'Search', line: 'The field sits at the bottom, by your thumb.'),
  (title: 'Streak', line: 'Days in a row, top right of every page.'),
  (title: 'Settings', line: 'The gear beside it: theme, reminders, week.'),
];

const List<_Place> _macPlaces = <_Place>[
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

const List<String> _sidebarNav = <String>[
  'Today',
  'Calendar',
  'Meadow',
  'Search',
];

const int _phoneCalendar = 2;
const int _phoneStreak = 6;
const int _phoneGear = 7;
const int _macStreak = 5;
const int _macGear = 6;
const int _streakCount = 4;

const Color _ring = Color.fromRGBO(184, 86, 106, 0.25);
const double _ringSpread = 4;
const double _pillHeight = 30;
const double _gearExtent = 36;
const double _barHeight = 64;
const double _barSide = 12;
const double _rowMinHeight = 50;
const double _titleTop = 52;

Future<void> _onPlatform(
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
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
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _settleHighlight(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _openTour(WidgetTester tester, {required bool phone}) async {
  tester.view.physicalSize = phone ? _phone : _mac;
  tester.view.devicePixelRatio = 1;
  if (phone) {
    tester.view.padding = const FakeViewPadding(
      top: _statusBar,
      bottom: _gestureBar,
    );
    tester.view.viewPadding = const FakeViewPadding(
      top: _statusBar,
      bottom: _gestureBar,
    );
  } else {
    tester.view.resetPadding();
    tester.view.resetViewPadding();
  }
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: _overrides(),
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
  while ((container.read(
        onboardingControllerProvider,
      ) as OnboardingFlowRunning).chapter !=
      OnboardingChapter.tour) {
    controller.next();
    await tester.pump();
  }
  await _settle(tester);
  expect(find.byType(TourChapter), findsOneWidget);
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

Finder _target(int number) => find.byKey(tourTargetKey(number));

Finder get _replicaBar => _inTour(find.byType(PhoneBottomBar));

Finder _pillIn(int target) => _inside(_target(target), find.byType(StreakPill));

BoxDecoration _pillFace(WidgetTester tester, int target) =>
    tester
            .widget<DecoratedBox>(
              _inside(_pillIn(target), find.byType(DecoratedBox)).first,
            )
            .decoration
        as BoxDecoration;

List<Rect> _rectsOf(WidgetTester tester, Finder finder) => <Rect>[
  for (final Element element in finder.evaluate())
    tester.getRect(
      find.byElementPredicate((Element other) => other == element),
    ),
];

void _expectPillRung(WidgetTester tester, int target, {required bool on}) {
  expect(tester.widget<StreakPill>(_pillIn(target)).highlighted, on);
  final BoxDecoration face = _pillFace(tester, target);
  final Iterable<BoxShadow> rings = (face.boxShadow ?? const <BoxShadow>[])
      .where(
        (BoxShadow shadow) =>
            shadow.spreadRadius == _ringSpread &&
            shadow.color.toARGB32() == _ring.toARGB32(),
      );
  expect(rings, hasLength(on ? 1 : 0), reason: 'ring on target $target');
  expect(
    face.color!.toARGB32() == Palette.coral.toARGB32(),
    on,
    reason: 'terracotta fill on target $target',
  );
}

void _expectTabPill(WidgetTester tester, ShellDestination? selected) {
  expect(tester.widget<PhoneBottomBar>(_replicaBar).selected, selected);
  final int pill = GlassTone.paper
      .pillFor(Theme.of(tester.element(_replicaBar)).brightness)
      .toARGB32();
  final Finder pills = _inside(
    _replicaBar,
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

void _expectHighlighted(
  WidgetTester tester,
  List<_Place> places,
  int? highlighted, {
  required bool numbered,
}) {
  for (final (int index, _Place place) in places.indexed) {
    final int number = index + 1;
    final bool on = number == highlighted;
    expect(
      tester.getSemantics(_line(number)),
      isSemantics(
        label: numbered
            ? '$number, ${place.title}, ${place.line}'
            : '${place.title}, ${place.line}',
        isSelected: on,
      ),
      reason: place.title,
    );
    expect(
      tester.widget<MapPlaceHighlight>(_target(number)).highlighted,
      on,
      reason: place.title,
    );
  }
}

void _expectRowsInOrder(
  WidgetTester tester,
  List<_Place> places, {
  required double below,
  required bool numbered,
}) {
  double above = below;
  for (final (int index, _Place place) in places.indexed) {
    final int number = index + 1;
    final Finder line = _line(number);
    expect(line, findsOneWidget, reason: place.title);
    expect(_inside(line, find.text(place.title)), findsOneWidget);
    expect(_inside(line, find.text(place.line)), findsOneWidget);
    if (numbered) {
      expect(_inside(line, find.text('$number')), findsOneWidget);
    }
    final Rect rect = tester.getRect(line);
    expect(rect.top, greaterThan(above), reason: place.title);
    above = rect.bottom;
  }
  expect(_line(places.length + 1), findsNothing);
}

void main() {
  testWidgets(
    'the phone tour lists seven rows and tapping one highlights its place',
    (WidgetTester tester) async {
      await _onPlatform(TargetPlatform.android, () async {
        await _openTour(tester, phone: true);

        expect(_inTour(find.text(_kicker)), findsOneWidget);
        expect(_inTour(find.text(_title)), findsOneWidget);
        expect(_inTour(find.text(_subtitle)), findsOneWidget);
        final Rect subtitle = tester.getRect(_inTour(find.text(_subtitle)));

        final Rect pill = tester.getRect(_pillIn(_phoneStreak));
        final Rect gear = tester.getRect(_target(_phoneGear));
        final StreakPill streak = tester.widget<StreakPill>(
          _pillIn(_phoneStreak),
        );
        expect(streak.form, StreakPillForm.header);
        expect(streak.count, _streakCount);
        expect(streak.numberOnly, isTrue);
        expect(
          _inside(_pillIn(_phoneStreak), find.text('$_streakCount')),
          findsOneWidget,
        );
        expect(pill.height, moreOrLessEquals(_pillHeight, epsilon: 0.01));
        expect(gear.width, moreOrLessEquals(_gearExtent, epsilon: 0.01));
        expect(gear.height, moreOrLessEquals(_gearExtent, epsilon: 0.01));
        expect(
          tester
              .widget<Icon>(_inside(_target(_phoneGear), find.byType(Icon)))
              .icon,
          Icons.settings_outlined,
        );
        expect(gear.left, greaterThan(pill.right));
        expect(pill.top, greaterThan(subtitle.bottom));
        expect(
          _rectsOf(tester, _inTour(find.text(_headerTitle))).where(
            (Rect title) =>
                title.right <= pill.left + 0.01 &&
                (title.center.dy - pill.center.dy).abs() < 2,
          ),
          hasLength(1),
        );

        _expectRowsInOrder(
          tester,
          _phonePlaces,
          below: gear.bottom,
          numbered: false,
        );
        for (int number = 1; number <= _phonePlaces.length; number++) {
          expect(
            tester.getSize(_line(number)).height,
            greaterThanOrEqualTo(_rowMinHeight - 0.01),
          );
        }

        expect(_replicaBar, findsOneWidget);
        final PhoneBottomBar bar = tester.widget<PhoneBottomBar>(_replicaBar);
        expect(bar.destinations, ShellDestination.primary);
        expect(bar.onSelect, isNull);
        expect(bar.onCapture, isNull);
        expect(bar.overScene, isFalse);
        expect(
          tester
              .widget<GlassSurface>(
                _inside(_replicaBar, find.byType(GlassSurface)),
              )
              .tone,
          GlassTone.paper,
        );
        final Rect tour = tester.getRect(_tour);
        final Rect barRect = tester.getRect(_replicaBar);
        expect(barRect.height, moreOrLessEquals(_barHeight, epsilon: 0.01));
        expect(barRect.left - tour.left, moreOrLessEquals(_barSide));
        expect(tour.right - barRect.right, moreOrLessEquals(_barSide));
        expect(
          barRect.top,
          greaterThan(tester.getRect(_line(_phonePlaces.length)).bottom),
        );
        expect(
          barRect.bottom,
          lessThanOrEqualTo(
            tester.getRect(find.byKey(onboardingControlBarKey)).top,
          ),
        );

        _expectHighlighted(tester, _phonePlaces, 1, numbered: false);
        _expectTabPill(tester, ShellDestination.today);
        _expectPillRung(tester, _phoneStreak, on: false);

        await tester.tap(_line(_phoneStreak));
        await _settleHighlight(tester);
        _expectHighlighted(tester, _phonePlaces, _phoneStreak, numbered: false);
        _expectPillRung(tester, _phoneStreak, on: true);
        _expectTabPill(tester, null);

        await tester.tap(_line(_phoneCalendar));
        await _settleHighlight(tester);
        _expectHighlighted(
          tester,
          _phonePlaces,
          _phoneCalendar,
          numbered: false,
        );
        _expectTabPill(tester, ShellDestination.calendar);
        _expectPillRung(tester, _phoneStreak, on: false);
        await _unmount(tester);
      });
    },
  );

  testWidgets('the macOS tour has six rows and highlights the streak pill', (
    WidgetTester tester,
  ) async {
    await _onPlatform(TargetPlatform.macOS, () async {
      await _openTour(tester, phone: false);

      final Rect tour = tester.getRect(_tour);
      final Rect kicker = tester.getRect(_inTour(find.text(_kicker)));
      expect(kicker.top - tour.top, moreOrLessEquals(_titleTop));
      expect(
        kicker.top,
        greaterThanOrEqualTo(
          tester.getRect(find.byKey(onboardingProgressKey)).bottom,
        ),
      );
      expect(_inTour(find.text(_title)), findsOneWidget);
      expect(_inTour(find.text(_subtitle)), findsNothing);

      _expectRowsInOrder(
        tester,
        _macPlaces,
        below: tester.getRect(_inTour(find.text(_title))).bottom,
        numbered: true,
      );

      for (final (int index, String label) in _sidebarNav.indexed) {
        expect(
          _inside(_target(index + 1), find.text(label)),
          findsOneWidget,
          reason: label,
        );
      }
      final StreakPill streak = tester.widget<StreakPill>(_pillIn(_macStreak));
      expect(streak.form, StreakPillForm.sidebar);
      expect(streak.count, _streakCount);
      expect(streak.numberOnly, isFalse);
      expect(
        _inside(_pillIn(_macStreak), find.text('$_streakCount days')),
        findsOneWidget,
      );
      expect(
        _inside(find.byKey(tourBadgeKey(_macStreak)), find.text('$_macStreak')),
        findsOneWidget,
      );
      expect(
        _inside(find.byKey(tourBadgeKey(_macGear)), find.text('$_macGear')),
        findsOneWidget,
      );
      final Finder gearGlyph = _inside(
        _target(_macGear),
        find.byType(IconStickerGlyphIcon),
      );
      expect(
        tester.widget<IconStickerGlyphIcon>(gearGlyph).glyph,
        IconStickerGlyph.gear,
      );
      final Rect search = tester.getRect(_target(_sidebarNav.length));
      final Rect pill = tester.getRect(_target(_macStreak));
      final Rect gear = tester.getRect(_target(_macGear));
      expect(pill.top, greaterThan(search.bottom));
      expect(gear.top, greaterThan(pill.bottom));
      expect(pill.left, moreOrLessEquals(search.left));
      expect(gear.left, moreOrLessEquals(search.left));

      _expectHighlighted(tester, _macPlaces, null, numbered: true);
      _expectPillRung(tester, _macStreak, on: false);

      final TestGesture mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(_line(_macStreak)));
      await _settleHighlight(tester);
      _expectHighlighted(tester, _macPlaces, _macStreak, numbered: true);
      _expectPillRung(tester, _macStreak, on: true);
      expect(
        tester.widget<IconStickerGlyphIcon>(gearGlyph).color.toARGB32(),
        isNot(Palette.onAccent.toARGB32()),
      );

      await mouse.moveTo(tester.getCenter(_line(_macGear)));
      await _settleHighlight(tester);
      _expectHighlighted(tester, _macPlaces, _macGear, numbered: true);
      _expectPillRung(tester, _macStreak, on: false);
      expect(
        tester.widget<IconStickerGlyphIcon>(gearGlyph).color.toARGB32(),
        Palette.onAccent.toARGB32(),
      );
      await mouse.removePointer();
      await tester.pump();
      await _unmount(tester);
    });
  });
}
