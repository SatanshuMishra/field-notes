import 'dart:math' as math;

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/core/capture_date.dart';
import 'package:field_notes/features/garden/garden.dart';
import 'package:field_notes/features/garden/model/meadow_focus.dart';
import 'package:field_notes/features/garden/model/meadow_key_provider.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/scene/meadow_plants.dart';
import 'package:field_notes/features/garden/scene/meadow_stage.dart';
import 'package:field_notes/features/garden/scene/meadow_terrain.dart'
    hide MeadowRange;
import 'package:field_notes/features/garden/scene/meadow_view.dart';
import 'package:field_notes/features/garden/scene/meadow_world.dart';
import 'package:field_notes/features/garden/sky/sky_location.dart';
import 'package:field_notes/features/garden/sky/sky_location_provider.dart';
import 'package:field_notes/features/garden/sky/sky_time.dart';
import 'package:field_notes/features/garden/widgets/meadow_details_panel.dart';
import 'package:field_notes/features/garden/widgets/meadow_details_sheet.dart';
import 'package:field_notes/features/garden/widgets/meadow_focus_stepper.dart';
import 'package:field_notes/features/garden/widgets/meadow_header.dart';
import 'package:field_notes/features/streak/journaled_dates_provider.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/garden_harness.dart';

const Size _phone = Size(384, 832);
const Size _window = Size(1140, 820);
const int _buildFrames = 6000;

final DateTime _noon = DateTime.utc(2026, 9, 28, 18);
final SkyLocation _edmonton = resolveSkyLocation(
  'America/Edmonton',
  const Duration(hours: -6),
);

String _dateOf(int year, int index) =>
    captureDateKey(DateTime(year, 1, 1 + index));

final List<Day> _scattered = <Day>[
  for (int index = 0; index < 272; index++)
    if (index % 3 != 1)
      dayOf(
        _dateOf(2026, index),
        mood: moodOrder[(index * 3 + index ~/ 11) % moodOrder.length],
      ),
];

final List<Day> _twentyInARow = <Day>[
  for (int day = 1; day <= 10; day++)
    dayOf(captureDateKey(DateTime(2026, 1, day)), mood: Mood.happy),
  for (int day = 11; day <= 20; day++)
    dayOf(captureDateKey(DateTime(2026, 1, day)), mood: Mood.sad),
];

Future<void> _pump(
  WidgetTester tester, {
  required TargetPlatform platform,
  List<Day>? days,
}) async {
  final bool phone = platform == TargetPlatform.android;
  tester.view.physicalSize = phone ? _phone : _window;
  tester.view.devicePixelRatio = 1;
  if (phone) {
    tester.view.padding = const FakeViewPadding(top: 34, bottom: 24);
    tester.view.viewPadding = const FakeViewPadding(top: 34, bottom: 24);
  }
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    gardenHarness(
      const GardenScreen(),
      platform: platform,
      overrides: <Override>[
        allDaysProvider.overrideWith(
          (Ref ref) => Stream<List<Day>>.value(days ?? _scattered),
        ),
        journalEntryCountsProvider.overrideWith(
          (Ref ref) => Stream<Map<String, int>>.value(const <String, int>{}),
        ),
        meadowKeyProvider.overrideWith((Ref ref) async => 24601),
        skyClockProvider.overrideWithValue(() => _noon),
        skyLocationProvider.overrideWith((Ref ref) async => _edmonton),
      ],
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<MeadowStageState> _grow(WidgetTester tester) async {
  final MeadowStageState state = tester.state<MeadowStageState>(
    find.byType(MeadowStage),
  );
  for (int i = 0; i < _buildFrames && !state.debugIsReady; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
    await tester.pump();
  }
  expect(state.debugIsReady, isTrue, reason: 'the meadow never finished');
  await tester.pump(const Duration(milliseconds: 400));
  return state;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

MeadowStage _stage(WidgetTester tester) =>
    tester.widget<MeadowStage>(find.byType(MeadowStage));

String _title(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(meadowFocusTitleKey)).data!;

double _panTarget(WidgetTester tester, MeadowRange range) {
  final MeadowStage stage = _stage(tester);
  final MeadowTerrain terrain = buildMeadowTerrain(
    seed: stage.seed,
    year: stage.year,
  );
  final List<double> xs = <double>[
    for (final MeadowPlant plant in buildMeadowPlants(
      seed: stage.seed,
      year: stage.year,
      terrain: terrain,
    ).plants)
      if (plant.dayIndex >= range.first &&
          plant.dayIndex <= range.last &&
          plant.dayIndex < stage.resolvedGrowthPoint)
        plant.x,
  ];
  final Size box = tester.getSize(find.byType(MeadowStage));
  final double scale = math.max(
    box.width / meadowWorldWidth,
    box.height / meadowWorldHeight,
  );
  final double visible = box.width / scale;
  final double centre = xs.reduce((double a, double b) => a + b) / xs.length;
  return (centre - visible / 2).clamp(
    0.0,
    math.max(0.0, meadowWorldWidth - visible),
  );
}

void main() {
  testWidgets('tapping a month focuses it and close reopens the details', (
    WidgetTester tester,
  ) async {
    await _pump(tester, platform: TargetPlatform.android);
    final MeadowStageState state = await _grow(tester);

    await tester.tap(find.byKey(meadowDetailsButtonKey));
    await _settle(tester);
    expect(find.byKey(meadowDetailsSheetKey), findsOneWidget);
    final double before = state.debugViewport!.pan;

    await tester.tap(find.text('Feb'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(state.debugIsPanning, isTrue);
    expect(find.byKey(meadowDetailsSheetKey), findsNothing);
    expect(find.byKey(meadowDockKey), findsNothing);
    expect(find.byKey(meadowFocusStepperKey), findsOneWidget);

    final MeadowYear year = _stage(tester).year;
    final MeadowFocus february = MeadowFocus.month(year, 1);
    expect(february.range, const MeadowRange(first: 31, last: 58, key: 'm1'));
    expect(_title(tester), 'February');
    final String counts = february
        .countsIn(year, growthPoint: year.limit)
        .label;
    expect(counts, matches(RegExp(r'^\d+ blooms$')));
    expect(
      find.descendant(
        of: find.byKey(meadowFocusStepperKey),
        matching: find.text(counts),
      ),
      findsOneWidget,
    );
    expect(_stage(tester).highlight, february.range);
    expect(_stage(tester).panTo, february.range);

    await tester.pump(const Duration(milliseconds: 600));
    expect(state.debugIsPanning, isFalse);
    final double target = _panTarget(tester, february.range);
    expect(state.debugViewport!.pan, closeTo(target, 0.01));
    expect(target, isNot(closeTo(before, 1)));

    final Rect stepper = tester.getRect(find.byKey(meadowFocusStepperKey));
    expect(stepper.left, 12);
    expect(stepper.right, _phone.width - 12);
    expect(stepper.bottom, _phone.height - 24 - 80 - 12);
    for (final Key key in <Key>[
      meadowFocusPreviousKey,
      meadowFocusNextKey,
      meadowFocusCloseKey,
    ]) {
      expect(tester.getSize(find.byKey(key)), const Size(48, 48));
    }
    expect(find.byTooltip('Previous month'), findsOneWidget);
    expect(find.byTooltip('Next month'), findsOneWidget);
    expect(find.byTooltip('Back to the year'), findsOneWidget);

    await tester.tap(find.byKey(meadowFocusNextKey));
    await _settle(tester);
    expect(_title(tester), 'March');
    expect(_stage(tester).highlight, MeadowFocus.month(year, 2).range);

    final Offset centre = tester.getCenter(find.byKey(meadowFocusTitleKey));
    await tester.dragFrom(centre, const Offset(60, 0));
    await _settle(tester);
    expect(_title(tester), 'February');
    await tester.dragFrom(centre, const Offset(-60, 0));
    await _settle(tester);
    expect(_title(tester), 'March');
    await tester.dragFrom(centre, const Offset(30, 0));
    await _settle(tester);
    expect(_title(tester), 'March');

    await tester.tap(find.byKey(meadowFocusPreviousKey));
    await _settle(tester);
    await tester.tap(find.byKey(meadowFocusPreviousKey));
    await _settle(tester);
    expect(_title(tester), 'January');
    await tester.tap(find.byKey(meadowFocusPreviousKey));
    await _settle(tester);
    expect(_title(tester), 'January');

    await tester.tap(find.byKey(meadowFocusCloseKey));
    await _settle(tester);
    expect(find.byKey(meadowFocusStepperKey), findsNothing);
    expect(find.byKey(meadowDetailsSheetKey), findsOneWidget);
    expect(find.text('Tap a month to find its flowers'), findsOneWidget);
    expect(_stage(tester).highlight, isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('on macOS a clicked month focuses, the arrows step it and Esc '
      'reopens the details', (WidgetTester tester) async {
    await _pump(tester, platform: TargetPlatform.macOS);

    await tester.tap(find.byKey(meadowDetailsButtonKey));
    await _settle(tester);
    expect(find.byKey(meadowDetailsPanelKey), findsOneWidget);
    await tester.tap(find.text('Feb'));
    await _settle(tester);
    expect(find.byKey(meadowDetailsPanelKey), findsNothing);
    expect(find.byKey(meadowDockKey), findsNothing);
    expect(_title(tester), 'February');
    final Rect stepper = tester.getRect(find.byKey(meadowFocusStepperKey));
    expect(stepper.width, 380);
    expect(stepper.center.dx, closeTo(_window.width / 2, 0.5));
    expect(stepper.bottom, _window.height - 20);
    expect(tester.getSize(find.byKey(meadowFocusNextKey)), const Size(40, 40));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await _settle(tester);
    expect(_title(tester), 'March');
    expect(_stage(tester).year.year, 2026);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await _settle(tester);
    expect(_title(tester), 'February');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await _settle(tester);
    expect(find.byKey(meadowFocusStepperKey), findsNothing);
    expect(find.byKey(meadowDetailsPanelKey), findsOneWidget);
    expect(find.byKey(meadowDockKey), findsOneWidget);
    expect(_stage(tester).highlight, isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a landmark with a range focuses and steps only through the '
      'landmarks that have one', (WidgetTester tester) async {
    await _pump(tester, platform: TargetPlatform.android, days: _twentyInARow);

    await tester.tap(find.byKey(meadowDetailsButtonKey));
    await _settle(tester);
    await tester.tap(find.text('This year so far'));
    await _settle(tester);
    await tester.tap(find.text('The old spruce'));
    await _settle(tester);
    expect(_title(tester), 'The old spruce');
    expect(find.byTooltip('Previous landmark'), findsOneWidget);
    expect(
      _stage(tester).highlight,
      const MeadowRange(first: 0, last: 19, key: 'l0'),
    );
    expect(
      find.descendant(
        of: find.byKey(meadowFocusStepperKey),
        matching: find.text('20 blooms'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(meadowFocusNextKey));
    await _settle(tester);
    expect(_title(tester), 'Mist in the hollow');
    await tester.tap(find.byKey(meadowFocusNextKey));
    await _settle(tester);
    expect(_title(tester), 'Butterflies');
    await tester.tap(find.byKey(meadowFocusNextKey));
    await _settle(tester);
    expect(_title(tester), 'Butterflies');

    await tester.tap(find.byKey(meadowFocusCloseKey));
    await _settle(tester);
    expect(find.byKey(meadowFocusStepperKey), findsNothing);
    expect(find.text('Tap one to find those days'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
