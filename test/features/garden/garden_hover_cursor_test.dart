import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/core/capture_date.dart';
import 'package:field_notes/features/garden/garden.dart';
import 'package:field_notes/features/garden/model/meadow_focus.dart';
import 'package:field_notes/features/garden/model/meadow_key_provider.dart';
import 'package:field_notes/features/garden/model/meadow_random.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/scene/meadow_plants.dart';
import 'package:field_notes/features/garden/scene/meadow_stage.dart';
import 'package:field_notes/features/garden/scene/meadow_stage_tooltip.dart';
import 'package:field_notes/features/garden/scene/meadow_terrain.dart'
    hide MeadowRange;
import 'package:field_notes/features/garden/scene/meadow_view.dart';
import 'package:field_notes/features/garden/sky/sky_location.dart';
import 'package:field_notes/features/garden/sky/sky_location_provider.dart';
import 'package:field_notes/features/garden/sky/sky_time.dart';
import 'package:field_notes/features/garden/widgets/meadow_focus_stepper.dart';
import 'package:field_notes/features/garden/widgets/meadow_glass_popover.dart';
import 'package:field_notes/features/garden/widgets/meadow_header.dart';
import 'package:field_notes/features/garden/widgets/meadow_study_controls.dart';
import 'package:field_notes/features/garden/widgets/meadow_tabs.dart';
import 'package:field_notes/features/garden/widgets/meadow_year_picker.dart';
import 'package:field_notes/features/streak/journaled_dates_provider.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/garden_harness.dart';
import 'support/meadow_stage_harness.dart';

const int _mousePointerId = 47;
const int _mouseDevice = 1;

const Color _ink = Color(0xFF4A3B2E);
const Color _white = Color(0xFFFFFFFF);
const Color _night = Color(0xFF2E2A24);

final int _light = _ink.withValues(alpha: 0.06).toARGB32();
final int _dark = _white.withValues(alpha: 0.12).toARGB32();

const Size _window = Size(1140, 820);
final DateTime _noon = DateTime.utc(2026, 9, 28, 18);
final SkyLocation _edmonton = resolveSkyLocation(
  'America/Edmonton',
  const Duration(hours: -6),
);

String _dateOf(int year, int index) =>
    captureDateKey(DateTime(year, 1, 1 + index));

final List<Day> _days = <Day>[
  for (int index = 0; index < 270; index += 2)
    dayOf(_dateOf(2026, index), mood: moodOrder[index % moodOrder.length]),
  for (int index = 0; index < 365; index += 3)
    dayOf(_dateOf(2025, index), mood: moodOrder[index % moodOrder.length]),
];

List<Day> _twentyInARow(int year) => <Day>[
  for (int day = 1; day <= 10; day++)
    dayOf(captureDateKey(DateTime(year, 1, day)), mood: Mood.happy),
  for (int day = 11; day <= 20; day++)
    dayOf(captureDateKey(DateTime(year, 1, day)), mood: Mood.sad),
];

const MeadowFocus _june = MeadowFocus(
  kind: MeadowFocusKind.month,
  index: 5,
  count: 12,
  range: MeadowRange(first: 151, last: 180, key: 'month-5'),
  title: 'June',
);

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
  final Matcher label;
  final int fill;
  final _Shape shape;
  final double? radius;
  final _Role role;
}

Finder _pressableAround(String text) => find
    .ancestor(of: find.text(text).last, matching: find.byType(Pressable))
    .first;

MouseCursor? _cursor() =>
    RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(_mouseDevice);

Finder _hoverFill(_Row row) => find.descendant(
  of: row.control,
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
    await mouse.moveTo(Offset.zero);
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
  await mouse.moveTo(Offset.zero);
  await tester.pump();
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void _view(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _pumpGarden(WidgetTester tester) async {
  _view(tester, _window);
  await tester.pumpWidget(
    gardenHarness(
      const GardenScreen(),
      platform: TargetPlatform.macOS,
      overrides: <Override>[
        allDaysProvider.overrideWith(
          (Ref ref) => Stream<List<Day>>.value(_days),
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

Future<void> _pumpOnNight(
  WidgetTester tester,
  TargetPlatform platform,
  Widget body,
) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: fieldNotesTheme(platform: platform),
      home: Scaffold(
        backgroundColor: _night,
        body: Padding(padding: const EdgeInsets.all(24), child: body),
      ),
    ),
  );
  await _settle(tester);
}

class _TabsHost extends StatefulWidget {
  const _TabsHost({required this.year});

  final MeadowYear year;

  @override
  State<_TabsHost> createState() => _TabsHostState();
}

class _TabsHostState extends State<_TabsHost> {
  MeadowRange? _highlight;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: MeadowTabs(
        year: widget.year,
        isCurrentYear: false,
        compact: false,
        growthPoint: widget.year.limit,
        highlight: _highlight,
        onHighlight: (MeadowRange? range) => setState(() => _highlight = range),
        onClose: () {},
        onFocusMonth: (int month) {},
        onFocusLandmark: (int landmark) {},
      ),
    );
  }
}

Widget _study({required bool compact}) => MeadowStudyControls(
  compact: compact,
  hourMinutes: 12 * 60,
  onHour: (int? minutes) {},
  limit: 365,
  daysInYear: 365,
  year: 2025,
  growthPoint: 200,
  onGrowth: (int point, bool growAnimated) {},
  moment: SkyMoment(instant: DateTime(2026, 9, 29, 12)),
  builder: (BuildContext context, MeadowStudyParts parts) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      parts.panel,
      const SizedBox(height: 12),
      if (compact)
        parts.replay
      else
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[parts.play, parts.replay],
        ),
    ],
  ),
);

Offset _flowerOn(WidgetTester tester, MeadowStageState state, MeadowYear year) {
  final int seed = meadowSeed(meadowStageKey, year.year);
  final MeadowTerrain terrain = buildMeadowTerrain(seed: seed, year: year);
  final MeadowPlants plants = buildMeadowPlants(
    seed: seed,
    year: year,
    terrain: terrain,
  );
  final int juneThirtieth = DateTime.utc(
    2025,
    6,
    30,
  ).difference(DateTime.utc(2025)).inDays;
  final MeadowPlant flower = plants.plants.singleWhere(
    (MeadowPlant plant) => plant.dayIndex == juneThirtieth,
  );
  return tester.getTopLeft(find.byType(MeadowStage)) +
      state.debugViewport!.toLocal(flower.heads.last);
}

void main() {
  testWidgets('every garden control shows the click cursor and hover', (
    WidgetTester tester,
  ) async {
    final TestGesture mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      pointer: _mousePointerId,
    );
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);

    await _pumpGarden(tester);
    await _expectRows(tester, mouse, <_Row>[
      _Row(
        'year picker pill',
        find.byKey(meadowYearPickerButtonKey),
        equals('Your meadows, year by year'),
        _dark,
        _Shape.rounded,
        20,
      ),
      _Row(
        'time of day pill',
        find.byKey(meadowTimeButtonKey),
        equals('Time of day'),
        _dark,
        _Shape.rounded,
        20,
      ),
      _Row(
        'details dock round',
        find.byKey(meadowDetailsButtonKey),
        equals('The year, day by day'),
        _dark,
        _Shape.circle,
      ),
      _Row(
        'full screen dock round',
        find.byKey(meadowFullScreenButtonKey),
        equals('Full screen'),
        _dark,
        _Shape.circle,
      ),
    ]);

    await tester.tap(find.byKey(meadowTimeButtonKey));
    await _settle(tester);
    await _expectRows(tester, mouse, <_Row>[
      _Row(
        'morning time row',
        _pressableAround('Morning'),
        equals('Morning, 8 am'),
        _dark,
        _Shape.rounded,
        12,
      ),
      _Row(
        'night time row',
        _pressableAround('Night'),
        equals('Night, 11 pm'),
        _dark,
        _Shape.rounded,
        12,
      ),
    ]);
    await tester.tapAt(const Offset(20, 300));
    await _settle(tester);

    await tester.tap(find.byKey(meadowYearPickerButtonKey));
    await _settle(tester);
    await _expectRows(tester, mouse, <_Row>[
      _Row(
        'this year row',
        find.byKey(meadowYearRowKey(2026)),
        allOf(startsWith('2026\n'), endsWith('This year, still growing')),
        _dark,
        _Shape.rounded,
        12,
      ),
      _Row(
        'last year row',
        find.byKey(meadowYearRowKey(2025)),
        startsWith('2025\n'),
        _dark,
        _Shape.rounded,
        12,
      ),
    ]);
    await tester.tapAt(const Offset(20, 300));
    await _settle(tester);

    await tester.pumpWidget(const SizedBox());
    _view(tester, const Size(1100, 900));
    await tester.pumpWidget(
      gardenHarness(
        _TabsHost(
          year: MeadowYear.build(
            days: _twentyInARow(2025),
            entryCounts: const <String, int>{},
            year: 2025,
            today: DateTime(2026, 3, 1, 9),
          ),
        ),
        platform: TargetPlatform.macOS,
      ),
    );
    await _settle(tester);
    await _expectRows(tester, mouse, <_Row>[
      _Row(
        'days tab',
        _pressableAround('The year, day by day'),
        equals('The year, day by day'),
        _light,
        _Shape.rounded,
        9,
      ),
      _Row(
        'landmarks tab',
        _pressableAround('Landmarks'),
        equals('Landmarks'),
        _light,
        _Shape.rounded,
        9,
      ),
      _Row(
        'details close',
        find.byKey(meadowDetailsCloseKey),
        equals('Close'),
        _light,
        _Shape.rounded,
        10,
      ),
      _Row(
        'january month',
        _pressableAround('Jan'),
        startsWith('January, 20 days planted'),
        _light,
        _Shape.rounded,
        8,
      ),
      _Row(
        'february month',
        _pressableAround('Feb'),
        equals('February, no days planted'),
        _light,
        _Shape.rounded,
        8,
      ),
    ]);

    await tester.tap(find.text('Landmarks'));
    await _settle(tester);
    await _expectRows(tester, mouse, <_Row>[
      _Row(
        'old spruce landmark',
        _pressableAround('The old spruce'),
        contains('The old spruce'),
        _light,
        _Shape.rounded,
        13,
      ),
      _Row(
        'mist landmark',
        _pressableAround('Mist in the hollow'),
        contains('Mist in the hollow'),
        _light,
        _Shape.rounded,
        13,
      ),
      _Row(
        'butterflies landmark',
        _pressableAround('Butterflies'),
        contains('Butterflies'),
        _light,
        _Shape.rounded,
        13,
      ),
    ]);

    _view(tester, const Size(1000, 600));
    await _pumpOnNight(
      tester,
      TargetPlatform.macOS,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          MeadowBackLink(onPressed: () {}),
          const SizedBox(height: 24),
          SizedBox(
            width: meadowDeskStepperWidth,
            child: MeadowFocusStepper(
              focus: _june,
              counts: '0 blooms',
              compact: false,
              onStep: (int step) {},
              onClose: () {},
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(width: 520, child: _study(compact: false)),
        ],
      ),
    );
    await _expectRows(tester, mouse, <_Row>[
      _Row(
        'back link',
        find.byType(MeadowBackLink),
        equals('Your meadow this year'),
        _dark,
        _Shape.rounded,
        6,
      ),
      _Row(
        'previous month',
        find.byKey(meadowFocusPreviousKey),
        equals('Previous month'),
        _dark,
        _Shape.circle,
      ),
      _Row(
        'next month',
        find.byKey(meadowFocusNextKey),
        equals('Next month'),
        _dark,
        _Shape.circle,
      ),
      _Row(
        'back to the year',
        find.byKey(meadowFocusCloseKey),
        equals('Back to the year'),
        _dark,
        _Shape.circle,
      ),
      _Row(
        'time of day slider',
        find.byKey(meadowHourSliderKey),
        equals('Time of day'),
        _dark,
        _Shape.rounded,
        9,
        _Role.slider,
      ),
      _Row(
        'grown through slider',
        find.byKey(meadowGrowthSliderKey),
        equals('Grown through'),
        _dark,
        _Shape.rounded,
        9,
        _Role.slider,
      ),
      _Row(
        'play the day pill',
        find.byKey(meadowStudyPlayKey),
        equals('Play the day'),
        _dark,
        _Shape.rounded,
        20,
      ),
      _Row(
        'replay pill',
        find.byKey(meadowReplayKey),
        equals('Replay the year'),
        _dark,
        _Shape.rounded,
        20,
      ),
    ]);

    _view(tester, const Size(390, 900));
    await _pumpOnNight(
      tester,
      TargetPlatform.android,
      SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                MeadowGlassButton(
                  key: const ValueKey<String>('glass-alone'),
                  label: 'Full screen',
                  onPressed: () {},
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: const SizedBox.square(dimension: 16),
                ),
                const SizedBox(width: 8),
                MeadowDockShadows(
                  child: MeadowGlassButton(
                    key: const ValueKey<String>('glass-grouped'),
                    label: 'This year',
                    onPressed: () {},
                    grouped: true,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: const SizedBox.square(dimension: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            MeadowTimeRow(
              label: 'Evening',
              sub: '7 pm',
              selected: false,
              compact: true,
              onPressed: () {},
            ),
            const SizedBox(height: 12),
            MeadowYearList(
              years: <MeadowYear>[meadowSampleYear()],
              openYear: 2024,
              compact: true,
              onPick: (int year) {},
            ),
            const SizedBox(height: 12),
            _study(compact: true),
          ],
        ),
      ),
    );
    await _expectRows(tester, mouse, <_Row>[
      _Row(
        'phone glass button',
        find.byKey(const ValueKey<String>('glass-alone')),
        equals('Full screen'),
        _dark,
        _Shape.rounded,
        14,
      ),
      _Row(
        'phone grouped glass button',
        find.byKey(const ValueKey<String>('glass-grouped')),
        equals('This year'),
        _dark,
        _Shape.rounded,
        14,
      ),
      _Row(
        'phone time row',
        _pressableAround('Evening'),
        equals('Evening, 7 pm'),
        _dark,
        _Shape.rounded,
        14,
      ),
      _Row(
        'phone year row',
        find.byKey(meadowYearRowKey(2025)),
        startsWith('2025\n'),
        _dark,
        _Shape.rounded,
        14,
      ),
      _Row(
        'phone replay button',
        find.byKey(meadowReplayKey),
        equals('Replay the year'),
        _dark,
        _Shape.rounded,
        14,
      ),
    ]);

    final MeadowYear sample = meadowSampleYear();
    final MeadowStageState page = await pumpMeadowStage(tester, year: sample);
    await growMeadow(tester, page);
    expect(find.bySemanticsLabel(RegExp(r'^Meadow, 2025')), findsOneWidget);
    final Rect stage = tester.getRect(find.byType(MeadowStage));
    await mouse.moveTo(stage.topLeft + const Offset(24, 24));
    await tester.pump();
    expect(_cursor(), isNot(SystemMouseCursors.click));
    expect(find.byType(MeadowStageTooltip), findsNothing);
    await mouse.moveTo(_flowerOn(tester, page, sample));
    await tester.pump();
    expect(_cursor(), SystemMouseCursors.click);
    expect(find.text('Mon, Jun 30'), findsOneWidget);
    expect(find.byType(MeadowStageTooltip), findsOneWidget);
    await mouse.moveTo(Offset.zero);
    await tester.pump();
    expect(find.byType(MeadowStageTooltip), findsNothing);

    final MeadowStageState phone = await pumpMeadowStage(
      tester,
      year: sample,
      box: const Size(400, 300),
      compact: true,
    );
    await growMeadow(tester, phone);
    final Offset flower = _flowerOn(tester, phone, sample);
    await mouse.moveTo(flower);
    await tester.pump();
    expect(_cursor(), SystemMouseCursors.click);
    expect(find.byType(MeadowStageTooltip), findsNothing);
    await mouse.moveTo(Offset.zero);
    await tester.pump();
    await tester.tapAt(flower);
    await tester.pump();
    expect(find.text('Mon, Jun 30'), findsOneWidget);
    expect(find.byType(MeadowStageTooltip), findsOneWidget);
  });
}
