import 'package:field_notes/app/app.dart';
import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/flowers/bloom_part.dart';
import 'package:field_notes/design/flowers/garden_plant_spec.dart';
import 'package:field_notes/design/flowers/root_art.dart';
import 'package:field_notes/domain/mood/mood.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/onboarding/chapters/day_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/garden_scene.dart';
import 'package:field_notes/features/onboarding/chapters/opening_chapter.dart';
import 'package:field_notes/features/onboarding/onboarding.dart';
import 'package:field_notes/features/reminders/reminder_providers.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../app/support/app_shell_harness.dart';
import '../../capture/core/capture_test_support.dart' show FakeNoteWriter;
import '../../settings/support/fake_settings_repository.dart';
import '../../settings/support/recording_reminder_scheduler.dart';

const Size _phone = Size(384, 832);
const Size _mac = Size(1280, 800);
const double _statusBar = 34;
const double _gestureBar = 24;

const String _moodTitle = 'Every feeling grows its own flower.';
const String _moodSubtitle = 'There are ten. Pick the one that fits today.';
const String _momentTitle = 'Write a little about today.';
const String _openingTitle = "Most days won't feel like a story.";

typedef _Placed = ({Rect rect, double opacity});

Finder _hint(ShellLayout layout) => find.text(switch (layout) {
  ShellLayout.sidebar => 'click anywhere to plant your first seed',
  ShellLayout.bottomBar => 'tap anywhere to plant your first seed',
});

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

Future<void> _rest(WidgetTester tester) async {
  await _settle(tester);
  await tester.pump(const Duration(milliseconds: 1500));
  await tester.pump();
}

Future<ProviderContainer> _pumpApp(
  WidgetTester tester,
  ShellLayout layout,
) async {
  final bool phone = layout == ShellLayout.bottomBar;
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
  return ProviderScope.containerOf(tester.element(find.byType(AppShell)));
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}

OnboardingController _controller(ProviderContainer container) =>
    container.read(onboardingControllerProvider.notifier);

OnboardingFlowRunning _running(ProviderContainer container) =>
    container.read(onboardingControllerProvider) as OnboardingFlowRunning;

OnboardingChapter _chapter(ProviderContainer container) =>
    _running(container).chapter;

Offset _middle(WidgetTester tester) {
  final Rect frame = tester.getRect(find.byType(OnboardingFrame));
  return Offset(frame.center.dx, frame.top + frame.height * 0.45);
}

Offset _swipeFrom(WidgetTester tester) {
  final Finder note = find.text(_momentTitle);
  return note.evaluate().isEmpty ? _middle(tester) : tester.getCenter(note);
}

Future<void> _fling(WidgetTester tester, double dx) async {
  await tester.flingFrom(_swipeFrom(tester), Offset(dx, 0), 800);
  await tester.pump();
}

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
  await tester.sendKeyEvent(key);
  await tester.pump();
}

Future<void> _tapPrimary(WidgetTester tester) async {
  await tester.tap(find.byKey(onboardingPrimaryKey));
  await tester.pump();
}

Future<void> _forward(WidgetTester tester, ShellLayout layout) =>
    layout == ShellLayout.bottomBar
    ? _fling(tester, -120)
    : _tapPrimary(tester);

Finder get _soil => find.byKey(gardenSoilKey);

Finder _flower(FlowerKind kind) => find.byKey(gardenFlowerKey(kind));

Finder _roots(FlowerKind kind) => find.byKey(gardenRootsKey(kind));

Finder _stakeReading(String name) =>
    find.descendant(of: find.byKey(gardenStakeKey), matching: find.text(name));

GardenPeonyPainter _peony(WidgetTester tester) =>
    tester.widget<CustomPaint>(_flower(FlowerKind.peony)).painter!
        as GardenPeonyPainter;

double _bloomGrowth(WidgetTester tester, FlowerKind kind) =>
    (tester.widget<CustomPaint>(_flower(kind)).painter! as GardenBloomPainter)
        .growth;

RootArt _rootArt(WidgetTester tester, FlowerKind kind) =>
    tester.widget<RootArt>(_roots(kind));

double _stemBaseX(FlowerKind kind) {
  final BloomShape stem = gardenPlantSpecFor(kind).parts.first as BloomShape;
  return (stem.commands.first as BloomMoveTo).x;
}

Offset _stemBase(WidgetTester tester, FlowerKind kind) {
  final RenderBox art = tester.renderObject<RenderBox>(_flower(kind));
  return art.localToGlobal(
    Offset(
      _stemBaseX(kind) / GardenPlantSpec.viewBoxWidth * art.size.width,
      art.size.height,
    ),
  );
}

double _holeX(WidgetTester tester) => tester.getRect(_soil).center.dx;

double _opacityOf(Element element) {
  double opacity = 1;
  element.visitAncestorElements((Element ancestor) {
    final Widget widget = ancestor.widget;
    if (widget is Opacity) {
      opacity *= widget.opacity;
    } else if (widget is FadeTransition) {
      opacity *= widget.opacity.value;
    }
    return widget is! OnboardingFrame;
  });
  return opacity;
}

List<_Placed> _texts(WidgetTester tester, Finder chapter) => <_Placed>[
  for (final Element text
      in find
          .descendant(of: chapter, matching: find.byType(RichText))
          .evaluate())
    (
      rect:
          (text.renderObject! as RenderBox).localToGlobal(Offset.zero) &
          (text.renderObject! as RenderBox).size,
      opacity: _opacityOf(text),
    ),
];

void _expectSame(
  List<_Placed> now,
  List<_Placed> rest, {
  required String reason,
}) {
  expect(now, hasLength(rest.length), reason: reason);
  for (int index = 0; index < rest.length; index++) {
    expect(
      now[index].rect.topLeft.dx,
      moreOrLessEquals(rest[index].rect.topLeft.dx, epsilon: 0.01),
      reason: '$reason text $index left',
    );
    expect(
      now[index].rect.topLeft.dy,
      moreOrLessEquals(rest[index].rect.topLeft.dy, epsilon: 0.01),
      reason: '$reason text $index top',
    );
    expect(
      now[index].opacity,
      moreOrLessEquals(rest[index].opacity, epsilon: 0.001),
      reason: '$reason text $index opacity',
    );
    expect(now[index].opacity, 1, reason: '$reason text $index full');
  }
}

void _expectScene(
  WidgetTester tester,
  FlowerKind kind, {
  required String reason,
}) {
  expect(_flower(kind), findsOneWidget, reason: '$reason flower');
  if (kind != FlowerKind.peony) {
    expect(_flower(FlowerKind.peony), findsNothing, reason: '$reason peony');
    expect(_bloomGrowth(tester, kind), 1, reason: '$reason grown at once');
  }
  expect(_roots(kind), findsOneWidget, reason: '$reason roots');
  expect(_rootArt(tester, kind).kind, kind, reason: '$reason roots kind');
  expect(_rootArt(tester, kind).mode, RootMode.still, reason: '$reason still');
  expect(
    _stakeReading(kind.label.toLowerCase()),
    findsOneWidget,
    reason: '$reason stake',
  );
  expect(
    _stakeReading('peony'),
    kind == FlowerKind.peony ? findsOneWidget : findsNothing,
    reason: '$reason no peony tag',
  );
}

Future<void> _grow(WidgetTester tester, ProviderContainer container) async {
  _controller(container)
    ..plant()
    ..markGrown();
  await _rest(tester);
}

void main() {
  testWidgets('planting plays once and returning shows the finished scene', (
    WidgetTester tester,
  ) async {
    for (final ShellLayout layout in ShellLayout.values) {
      await _onLayout(layout, () async {
        final String name = layout.name;
        final ProviderContainer container = await _pumpApp(tester, layout);
        expect(_hint(layout), findsOneWidget, reason: name);
        expect(_soil, findsOneWidget, reason: name);
        expect(_flower(FlowerKind.peony), findsNothing, reason: name);
        expect(_roots(FlowerKind.peony), findsNothing, reason: name);
        final State scene = tester.state(find.byType(GardenScene));

        await tester.tap(find.byType(OpeningChapter));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(_running(container).draft.planted, isTrue, reason: name);
        expect(find.byKey(gardenPlantingKey), findsOneWidget, reason: name);
        expect(_peony(tester).growth.isAnimating, isTrue, reason: name);
        expect(
          _rootArt(tester, FlowerKind.peony).mode,
          RootMode.open,
          reason: name,
        );
        await tester.pump(const Duration(milliseconds: 3000));
        await tester.pump();
        expect(_running(container).draft.grown, isTrue, reason: name);
        await tester.pump();
        expect(find.byKey(gardenPlantingKey), findsNothing, reason: name);
        expect(
          _rootArt(tester, FlowerKind.peony).mode,
          RootMode.still,
          reason: name,
        );

        await _forward(tester, layout);
        await _rest(tester);
        expect(_chapter(container), OnboardingChapter.day, reason: name);
        expect(
          identical(tester.state(find.byType(GardenScene)), scene),
          isTrue,
        );

        if (layout == ShellLayout.bottomBar) {
          await _fling(tester, 120);
        } else {
          await _key(tester, LogicalKeyboardKey.arrowLeft);
        }
        expect(_chapter(container), OnboardingChapter.opening, reason: name);
        expect(_peony(tester).growth.value, 1, reason: '$name no replay');
        expect(_peony(tester).growth.isAnimating, isFalse, reason: name);
        expect(find.byKey(gardenPlantingKey), findsNothing, reason: name);
        expect(
          _rootArt(tester, FlowerKind.peony).mode,
          RootMode.still,
          reason: name,
        );
        expect(_hint(layout), findsNothing, reason: name);
        expect(
          tester
              .widget<Opacity>(
                find
                    .descendant(
                      of: find.byKey(openingHeadingKey),
                      matching: find.byType(Opacity),
                    )
                    .first,
              )
              .opacity,
          1,
          reason: '$name heading shown at once',
        );
        expect(
          identical(tester.state(find.byType(GardenScene)), scene),
          isTrue,
        );

        _controller(container).start();
        await _settle(tester);
        expect(_chapter(container), OnboardingChapter.opening, reason: name);
        expect(_running(container).draft.planted, isFalse, reason: name);
        expect(_flower(FlowerKind.peony), findsNothing, reason: name);
        expect(_hint(layout), findsOneWidget, reason: name);
        await tester.tap(find.byType(OpeningChapter));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.byKey(gardenPlantingKey), findsOneWidget, reason: name);
        expect(_peony(tester).growth.isAnimating, isTrue, reason: name);
        await tester.pump(const Duration(seconds: 4));
        await _unmount(tester);
      });
    }
  });

  testWidgets(
    'Mood keeps the opening scene, slides it up and shows the new copy',
    (WidgetTester tester) async {
      for (final ShellLayout layout in ShellLayout.values) {
        await _onLayout(layout, () async {
          final String name = layout.name;
          final bool phone = layout == ShellLayout.bottomBar;
          final ProviderContainer container = await _pumpApp(tester, layout);
          await _grow(tester, container);
          final State scene = tester.state(find.byType(GardenScene));
          final Rect soil = tester.getRect(_soil);
          final Offset base = _stemBase(tester, FlowerKind.peony);

          await _forward(tester, layout);
          expect(_chapter(container), OnboardingChapter.day, reason: name);
          await tester.pump(const Duration(milliseconds: 600));
          final double midway = soil.top - tester.getRect(_soil).top;
          expect(midway, greaterThan(0), reason: '$name sliding');
          expect(midway, lessThan(phone ? 72 : 118), reason: '$name sliding');
          await tester.pump(const Duration(milliseconds: 700));
          await tester.pump();

          expect(
            identical(tester.state(find.byType(GardenScene)), scene),
            isTrue,
          );
          expect(
            soil.top - tester.getRect(_soil).top,
            moreOrLessEquals(phone ? 72 : 118),
            reason: name,
          );
          expect(
            _stemBase(tester, FlowerKind.peony).dy,
            moreOrLessEquals(base.dy - (phone ? 72 : 118)),
            reason: name,
          );
          expect(_peony(tester).growth.value, 1, reason: '$name not regrown');
          expect(_peony(tester).growth.isAnimating, isFalse, reason: name);
          expect(_stakeReading('peony'), findsOneWidget, reason: name);

          await tester.pump(const Duration(milliseconds: 500));
          expect(find.text(_moodTitle), findsOneWidget, reason: name);
          expect(find.text(_moodSubtitle), findsOneWidget, reason: name);
          expect(find.text('How was today, honestly?'), findsNothing);
          expect(find.textContaining('swipe for'), findsNothing);
          expect(find.textContaining('one flower a day'), findsNothing);

          final List<Rect> tiles = <Rect>[
            for (final Mood mood in moodOrder)
              tester.getRect(find.byKey(dayMoodKey(mood))),
          ];
          final Set<double> rows = <double>{
            for (final Rect tile in tiles) tile.center.dy.roundToDouble(),
          };
          final Set<double> columns = <double>{
            for (final Rect tile in tiles) tile.center.dx.roundToDouble(),
          };
          final Rect frame = tester.getRect(find.byType(OnboardingFrame));
          if (phone) {
            expect(rows, hasLength(2), reason: name);
            expect(columns, hasLength(5), reason: name);
            expect(tiles.first.height, 72, reason: name);
            expect(tiles.first.left, 12, reason: name);
            expect(tiles[4].right, moreOrLessEquals(_phone.width - 12));
            expect(
              tiles.last.bottom,
              moreOrLessEquals(_phone.height - _gestureBar - 80),
              reason: name,
            );
          } else {
            expect(rows, hasLength(1), reason: name);
            expect(columns, hasLength(10), reason: name);
            expect(tiles.first.size, const Size(76, 88), reason: name);
            expect(
              tiles.first.bottom,
              moreOrLessEquals(frame.bottom - 74),
              reason: name,
            );
            expect(
              (tiles.first.left + tiles.last.right) / 2,
              moreOrLessEquals(frame.center.dx),
              reason: name,
            );
            expect(
              tester.getRect(find.text('a day')).top - frame.top,
              greaterThanOrEqualTo(52),
              reason: name,
            );
            expect(
              tester.getRect(find.text(_moodTitle)).top - frame.top,
              greaterThanOrEqualTo(52),
              reason: name,
            );
          }
          await _unmount(tester);
        });
      }
    },
  );

  testWidgets(
    'picking a flower regrows it with its roots and names it on the stake',
    (WidgetTester tester) async {
      for (final ShellLayout layout in ShellLayout.values) {
        await _onLayout(layout, () async {
          final String name = layout.name;
          final ProviderContainer container = await _pumpApp(tester, layout);
          await _grow(tester, container);
          await _forward(tester, layout);
          await _rest(tester);
          expect(_chapter(container), OnboardingChapter.day, reason: name);
          expect(_stakeReading('peony'), findsOneWidget, reason: name);

          await tester.tap(find.byKey(dayMoodKey(Mood.love)));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(_running(container).draft.mood, Mood.love, reason: name);
          expect(_flower(FlowerKind.peony), findsNothing, reason: name);
          expect(_flower(FlowerKind.rose), findsOneWidget, reason: name);
          final double growing = _bloomGrowth(tester, FlowerKind.rose);
          expect(growing, greaterThan(0), reason: name);
          expect(growing, lessThan(1), reason: name);
          expect(_rootArt(tester, FlowerKind.rose).mode, RootMode.grow);
          expect(_stakeReading('rose'), findsOneWidget, reason: name);
          expect(_stakeReading('Loved'), findsNothing, reason: name);
          await tester.pump(const Duration(milliseconds: 800));
          expect(_bloomGrowth(tester, FlowerKind.rose), 1, reason: name);

          for (final Mood mood in moodOrder) {
            await tester.tap(find.byKey(dayMoodKey(mood)));
            await tester.pump();
            await tester.pump(const Duration(seconds: 1));
            final FlowerKind kind = mood.flower;
            expect(_flower(kind), findsOneWidget, reason: '$name $kind');
            expect(_roots(kind), findsOneWidget, reason: '$name $kind');
            expect(
              _stakeReading(kind.label.toLowerCase()),
              findsOneWidget,
              reason: '$name $kind',
            );
            expect(
              (_stemBase(tester, kind).dx - _holeX(tester)).abs(),
              lessThanOrEqualTo(2),
              reason: '$name ${kind.name} stem base',
            );
          }
          await _unmount(tester);
        });
      }
    },
  );

  testWidgets('the picked flower survives going forward and back', (
    WidgetTester tester,
  ) async {
    for (final ShellLayout layout in ShellLayout.values) {
      await _onLayout(layout, () async {
        final String name = layout.name;
        final bool phone = layout == ShellLayout.bottomBar;
        final ProviderContainer container = await _pumpApp(tester, layout);
        await _grow(tester, container);
        await _forward(tester, layout);
        await _rest(tester);
        await tester.tap(find.byKey(dayMoodKey(Mood.calm)));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        _controller(container).setNote('A first line about today');
        await tester.pump();

        Future<void> twiceForward(String route) async {
          await _forward(tester, layout);
          await _settle(tester);
          expect(_chapter(container), OnboardingChapter.moment, reason: route);
          await _forward(tester, layout);
          await _settle(tester);
          if (phone) {
            expect(
              _running(container).draft.showingOtherWays,
              isTrue,
              reason: route,
            );
          } else {
            expect(_chapter(container), OnboardingChapter.month, reason: route);
          }
          expect(find.byType(GardenScene), findsNothing, reason: route);
        }

        final List<(String, Future<void> Function())> routes =
            <(String, Future<void> Function())>[
              if (phone)
                (
                  'swipe',
                  () async {
                    await _fling(tester, 120);
                    await _settle(tester);
                    await _fling(tester, 120);
                  },
                ),
              (
                'back button',
                () async {
                  await tester.tap(find.byKey(onboardingBackKey));
                  await _settle(tester);
                  await tester.tap(find.byKey(onboardingBackKey));
                  await tester.pump();
                },
              ),
              (
                'progress marks',
                () async {
                  await tester.tap(
                    find.descendant(
                      of: find.byKey(onboardingProgressKey),
                      matching: find.bySemanticsLabel('A day'),
                    ),
                  );
                  await tester.pump();
                },
              ),
              if (!phone)
                (
                  'keys',
                  () async {
                    await _key(tester, LogicalKeyboardKey.arrowLeft);
                    await _settle(tester);
                    await _key(tester, LogicalKeyboardKey.arrowLeft);
                  },
                ),
            ];

        for (final (String route, Future<void> Function() back) in routes) {
          final String reason = '$name $route';
          await twiceForward(reason);
          await back();
          expect(_chapter(container), OnboardingChapter.day, reason: reason);
          _expectScene(tester, FlowerKind.lavender, reason: reason);
          await _rest(tester);
          _expectScene(tester, FlowerKind.lavender, reason: reason);
          expect(_running(container).draft.mood, Mood.calm, reason: reason);
        }
        await _unmount(tester);
      });
    }
  });

  testWidgets(
    'dragging moves the Mood text but not the scene and everything is restored',
    (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await _onLayout(ShellLayout.bottomBar, () async {
        final ProviderContainer container = await _pumpApp(
          tester,
          ShellLayout.bottomBar,
        );
        await _grow(tester, container);
        final Finder opening = find.byType(OpeningChapter);
        final List<_Placed> openingRest = _texts(tester, opening);
        expect(openingRest, isNotEmpty);

        await _fling(tester, -120);
        await _rest(tester);
        expect(_chapter(container), OnboardingChapter.day);
        final Finder day = find.byType(DayChapter);
        final List<_Placed> dayRest = _texts(tester, day);
        final Finder title = find.text(_moodTitle);
        final Rect titleRest = tester.getRect(title);
        final Rect flowerRest = tester.getRect(_flower(FlowerKind.peony));
        final Rect soilRest = tester.getRect(_soil);
        final Rect stakeRest = tester.getRect(find.byKey(gardenStakeKey));
        final Offset baseRest = _stemBase(tester, FlowerKind.peony);

        final TestGesture gesture = await tester.startGesture(_middle(tester));
        await gesture.moveBy(const Offset(-20, 0));
        await tester.pump();
        await gesture.moveBy(const Offset(-30, 0));
        await tester.pump();
        expect(
          tester.getRect(title).left,
          moreOrLessEquals(titleRest.left - 50 * 0.6),
        );
        expect(
          _opacityOf(title.evaluate().single),
          moreOrLessEquals(1 - 50 / 260),
        );
        expect(tester.getRect(_flower(FlowerKind.peony)), flowerRest);
        expect(tester.getRect(_soil), soilRest);
        expect(tester.getRect(find.byKey(gardenStakeKey)), stakeRest);
        expect(
          tester.getRect(find.byKey(dayMoodKey(Mood.happy))).left,
          lessThan(12),
        );

        await gesture.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(_chapter(container), OnboardingChapter.day);
        _expectSame(_texts(tester, day), dayRest, reason: 'mood after a drag');

        await _fling(tester, -120);
        await _rest(tester);
        expect(_chapter(container), OnboardingChapter.moment);
        await _fling(tester, 120);
        await _rest(tester);
        expect(_chapter(container), OnboardingChapter.day);
        _expectSame(
          _texts(tester, day),
          dayRest,
          reason: 'mood after swiping back from capture',
        );
        expect(tester.getRect(_soil), soilRest);
        expect(
          _stemBase(tester, FlowerKind.peony).dx,
          moreOrLessEquals(baseRest.dx),
        );
        expect(
          _stemBase(tester, FlowerKind.peony).dy,
          moreOrLessEquals(baseRest.dy),
        );

        await _fling(tester, 120);
        await _rest(tester);
        expect(_chapter(container), OnboardingChapter.opening);
        _expectSame(
          _texts(tester, opening),
          openingRest,
          reason: 'opening after swiping back',
        );
        expect(find.bySemanticsLabel(_openingTitle), findsOneWidget);
        await _unmount(tester);
      });
      semantics.dispose();
    },
  );
}
