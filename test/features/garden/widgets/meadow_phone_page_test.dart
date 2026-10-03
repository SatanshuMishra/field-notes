import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/shell/phone_bottom_bar.dart';
import 'package:field_notes/app/shell/shell_content.dart';
import 'package:field_notes/design/glass/glass.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/core/capture_date.dart';
import 'package:field_notes/features/garden/garden.dart';
import 'package:field_notes/features/garden/model/meadow_key_provider.dart';
import 'package:field_notes/features/garden/model/meadow_view_state.dart';
import 'package:field_notes/features/garden/scene/meadow_plants.dart';
import 'package:field_notes/features/garden/scene/meadow_stage.dart';
import 'package:field_notes/features/garden/scene/meadow_terrain.dart'
    hide MeadowRange;
import 'package:field_notes/features/garden/sky/sky_location.dart';
import 'package:field_notes/features/garden/sky/sky_location_provider.dart';
import 'package:field_notes/features/garden/sky/sky_time.dart';
import 'package:field_notes/features/garden/widgets/meadow_details_sheet.dart';
import 'package:field_notes/features/garden/widgets/meadow_glass_popover.dart';
import 'package:field_notes/features/garden/widgets/meadow_header.dart';
import 'package:field_notes/features/garden/widgets/meadow_study_controls.dart';
import 'package:field_notes/features/garden/widgets/meadow_tabs.dart';
import 'package:field_notes/features/garden/widgets/meadow_year_picker.dart';
import 'package:field_notes/features/streak/journaled_dates_provider.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../app/support/app_shell_harness.dart';
import '../support/garden_harness.dart';

const double _phoneHeight = 832;
const Size _phone = Size(384, _phoneHeight);
const double _statusBar = 34;
const double _gestureBar = 24;
const double _headerBottom = _statusBar + 44;
const double _dockBottom = _phoneHeight - _gestureBar - 80 - 12;
const int _buildFrames = 6000;

final DateTime _noon = DateTime.utc(2026, 9, 28, 18);
final SkyLocation _edmonton = resolveSkyLocation(
  'America/Edmonton',
  const Duration(hours: -6),
);

String _dateOf(int year, int index) =>
    captureDateKey(DateTime(year, 1, 1 + index));

final List<Day> _days = <Day>[
  for (int index = 0; index < 272; index++)
    if (index % 3 != 1)
      dayOf(
        _dateOf(2026, index),
        mood: moodOrder[(index * 3 + index ~/ 11) % moodOrder.length],
      ),
  for (int index = 0; index < 365; index += 2)
    dayOf(_dateOf(2025, index), mood: moodOrder[index % moodOrder.length]),
];

List<Override> _sceneOverrides() => <Override>[
  allDaysProvider.overrideWith((Ref ref) => Stream<List<Day>>.value(_days)),
  skyClockProvider.overrideWithValue(() => _noon),
  skyLocationProvider.overrideWith((Ref ref) async => _edmonton),
];

void _phoneView(WidgetTester tester) {
  tester.view.padding = const FakeViewPadding(
    top: _statusBar,
    bottom: _gestureBar,
  );
  tester.view.viewPadding = const FakeViewPadding(
    top: _statusBar,
    bottom: _gestureBar,
  );
  addTearDown(tester.view.reset);
}

Future<ProviderContainer> _pumpShellMeadow(WidgetTester tester) async {
  _phoneView(tester);
  await pumpShell(
    tester,
    const AppShell(),
    platform: TargetPlatform.android,
    surface: _phone,
    overrides: _sceneOverrides(),
  );
  await tester.tap(find.byKey(const ValueKey<String>('tab-garden')));
  await tester.pump();
  await tester.pump();
  return ProviderScope.containerOf(tester.element(find.byType(GardenScreen)));
}

Future<ProviderContainer> _pumpGarden(WidgetTester tester) async {
  tester.view.physicalSize = _phone;
  tester.view.devicePixelRatio = 1;
  _phoneView(tester);
  await tester.pumpWidget(
    gardenHarness(
      const GardenScreen(),
      platform: TargetPlatform.android,
      overrides: <Override>[
        ..._sceneOverrides(),
        journalEntryCountsProvider.overrideWith(
          (Ref ref) => Stream<Map<String, int>>.value(const <String, int>{}),
        ),
        meadowKeyProvider.overrideWith((Ref ref) async => 24601),
      ],
    ),
  );
  await tester.pump();
  await tester.pump();
  return ProviderScope.containerOf(tester.element(find.byType(GardenScreen)));
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

Rect _rect(WidgetTester tester, Key key) => tester.getRect(find.byKey(key));

Color? _fillOf(WidgetTester tester, Finder of) => tester
    .widgetList<DecoratedBox>(
      find.descendant(of: of, matching: find.byType(DecoratedBox)),
    )
    .map((DecoratedBox box) => box.decoration)
    .whereType<BoxDecoration>()
    .map((BoxDecoration decoration) => decoration.color)
    .firstWhere((Color? colour) => colour != null, orElse: () => null);

bool _isAncestor(RenderObject ancestor, RenderObject node) {
  for (RenderObject? walk = node.parent; walk != null; walk = walk.parent) {
    if (identical(walk, ancestor)) {
      return true;
    }
  }
  return false;
}

List<RenderCustomPaint> _customPaintsBelow(RenderObject root) {
  final List<RenderCustomPaint> found = <RenderCustomPaint>[];
  void visit(RenderObject node) {
    if (node is RenderCustomPaint) {
      found.add(node);
    }
    node.visitChildren(visit);
  }

  root.visitChildren(visit);
  return found;
}

void _expectGroupedDock(
  WidgetTester tester, {
  required BackdropKey shell,
  required int glassButtons,
}) {
  final Finder dock = find.byKey(meadowDockKey);
  final List<MeadowGlassButton> buttons = tester
      .widgetList<MeadowGlassButton>(
        find.descendant(of: dock, matching: find.byType(MeadowGlassButton)),
      )
      .toList();
  expect(buttons, hasLength(glassButtons));
  for (final MeadowGlassButton button in buttons) {
    expect(button.grouped, isTrue, reason: '${button.key}');
  }

  final List<RenderBackdropFilter> blurs = tester
      .renderObjectList<RenderBackdropFilter>(
        find.descendant(of: dock, matching: find.byType(BackdropFilter)),
      )
      .toList();
  expect(blurs, hasLength(glassButtons));
  final BackdropKey? group = blurs.first.backdropKey;
  expect(group, isNotNull);
  expect(group, isNot(shell));
  for (final RenderBackdropFilter blur in blurs) {
    expect(blur.backdropKey, group);
  }

  final RenderMeadowDockShadows shadows = tester
      .renderObject<RenderMeadowDockShadows>(
        find.ancestor(of: dock, matching: find.byType(MeadowDockShadows)),
      );
  for (final RenderBackdropFilter blur in blurs) {
    expect(_isAncestor(shadows, blur), isTrue);
  }
  expect(shadows.shadows, hasLength(glassButtons));
  for (final GlassShadowPainter shadow in shadows.shadows) {
    expect(shadow.shadows, GlassColors.scene.shadows);
    expect(
      shadow.borderRadius,
      const BorderRadius.all(Radius.circular(meadowPhoneDockRadius)),
    );
  }

  final List<RenderCustomPaint> below = _customPaintsBelow(shadows);
  expect(below, isNotEmpty);
  for (final RenderCustomPaint paint in below) {
    expect(paint.painter, isNot(isA<GlassShadowPainter>()));
    expect(paint.foregroundPainter, isNot(isA<GlassShadowPainter>()));
  }
}

void main() {
  testWidgets(
    'the phone meadow is full-bleed with its dock above the tab bar',
    (WidgetTester tester) async {
      final ProviderContainer container = await _pumpShellMeadow(tester);

      final Rect scene = tester.getRect(find.byType(MeadowStage));
      expect(scene, Offset.zero & _phone);
      expect(tester.getRect(find.byType(ShellContent)), scene);
      expect(_stage(tester).compact, isTrue);
      expect(_stage(tester).covers, isTrue);

      final Rect title = tester.getRect(find.byKey(meadowTitleKey));
      expect(find.text('your meadow'), findsOneWidget);
      expect(find.text('Every day, a bloom'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('your meadow')).dy,
        _headerBottom + 12,
      );
      expect(tester.getTopLeft(find.text('your meadow')).dx, 18);
      expect(title.top, greaterThan(_headerBottom));
      expect(scene.contains(title.center), isTrue);
      expect(
        tester.widget<Text>(find.byKey(meadowTitleKey)).style!.fontSize,
        26,
      );
      expect(find.textContaining('so far in 2026'), findsOneWidget);

      final Rect dock = _rect(tester, meadowDockKey);
      final Rect bar = tester.getRect(find.byType(PhoneBottomBar));
      expect(dock.left, 12);
      expect(dock.right, _phone.width - 12);
      expect(dock.bottom, _dockBottom);
      expect(dock.bottom, lessThan(bar.top));
      final List<Rect> buttons = <Rect>[
        for (final Key key in <Key>[
          meadowYearPickerButtonKey,
          meadowTimeButtonKey,
          meadowDetailsButtonKey,
          meadowFullScreenButtonKey,
        ])
          _rect(tester, key),
      ];
      for (int index = 0; index < buttons.length; index++) {
        expect(buttons[index].height, 48);
        expect(buttons[index].bottom, dock.bottom);
        if (index > 0) {
          expect(
            buttons[index].left,
            closeTo(buttons[index - 1].right + 8, 0.01),
          );
        }
      }
      expect(buttons.first.left, closeTo(dock.left, 0.01));
      expect(buttons.last.right, closeTo(dock.right, 0.01));
      expect(buttons[2].width, 48);
      expect(buttons[3].width, 48);
      expect(
        buttons[1].width,
        closeTo(dock.width - buttons[0].width - 48 * 2 - 8 * 3, 0.01),
      );
      expect(
        find.descendant(
          of: find.byKey(meadowYearPickerButtonKey),
          matching: find.text('2026'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(meadowTimeButtonKey),
          matching: find.text('Now'),
        ),
        findsOneWidget,
      );
      expect(find.byTooltip(meadowDetailsLabel), findsOneWidget);
      expect(find.byTooltip(meadowFullScreenLabel), findsOneWidget);
      expect(find.byKey(meadowStudyPanelKey), findsNothing);
      expect(find.byKey(meadowThisYearButtonKey), findsNothing);

      container
          .read(meadowViewStateProvider.notifier)
          .openYear(2025, currentYear: 2026);
      await _settle(tester);
      expect(find.text('meadow study'), findsOneWidget);
      expect(find.text('Your meadow, 2025'), findsOneWidget);
      final List<Rect> study = <Rect>[
        for (final Key key in <Key>[
          meadowThisYearButtonKey,
          meadowYearPickerButtonKey,
          meadowReplayKey,
          meadowDetailsButtonKey,
          meadowFullScreenButtonKey,
        ])
          _rect(tester, key),
      ];
      for (int index = 1; index < study.length; index++) {
        expect(study[index].left, closeTo(study[index - 1].right + 8, 0.01));
        expect(study[index].height, 48);
      }
      expect(study.first.left, closeTo(12, 0.01));
      expect(study.last.right, closeTo(_phone.width - 12, 0.01));
      expect(find.text(meadowBackCompactLabel), findsOneWidget);
      expect(
        _fillOf(tester, find.byKey(meadowReplayKey))!.toARGB32(),
        Palette.coral.toARGB32(),
      );
      expect(find.byKey(meadowTimeButtonKey), findsNothing);
      final Rect panel = _rect(tester, meadowStudyPanelKey);
      expect(panel.left, 12);
      expect(panel.right, _phone.width - 12);
      expect(panel.bottom, _dockBottom - 60);
      expect(find.text('Time of day'), findsOneWidget);
      expect(find.text('Grown through'), findsOneWidget);
      expect(_rect(tester, meadowHourSliderKey).height, 48);

      await tester.tap(find.byKey(meadowThisYearButtonKey));
      await _settle(tester);
      expect(container.read(meadowViewStateProvider).studyYear, isNull);
      expect(find.byKey(meadowStudyPanelKey), findsNothing);
    },
  );

  testWidgets(
    'the phone year and time pickers float as glass and details open as a '
    'sheet',
    (WidgetTester tester) async {
      await _pumpShellMeadow(tester);
      final Rect dock = _rect(tester, meadowDockKey);

      await tester.tap(find.byKey(meadowYearPickerButtonKey));
      await _settle(tester);
      final Rect years = _rect(tester, meadowPopoverKey);
      expect(years.left, 12);
      expect(years.right, _phone.width - 12);
      expect(years.bottom, dock.bottom - 56);
      expect(years.height, lessThanOrEqualTo(_phone.height * 0.62));
      expect(
        find.descendant(
          of: find.byKey(meadowPopoverKey),
          matching: find.byType(BackdropFilter),
        ),
        findsOneWidget,
      );
      expect(
        _fillOf(tester, find.byKey(meadowPopoverKey))!.toARGB32(),
        meadowGlassFill.toARGB32(),
      );
      expect(
        tester
            .widget<ColoredBox>(
              find.descendant(
                of: find.byKey(meadowPopoverScrimKey),
                matching: find.byType(ColoredBox),
              ),
            )
            .color
            .toARGB32(),
        meadowPopoverScrim.toARGB32(),
      );
      expect(find.text('your meadows'), findsOneWidget);
      expect(find.byKey(meadowYearRowKey(2026)), findsOneWidget);
      expect(find.byKey(meadowYearRowKey(2025)), findsOneWidget);

      await tester.tapAt(const Offset(192, 200));
      await _settle(tester);
      expect(find.byKey(meadowPopoverKey), findsNothing);
      expect(find.byKey(meadowYearRowKey(2026)), findsNothing);

      await tester.tap(find.byKey(meadowTimeButtonKey));
      await _settle(tester);
      final Rect times = _rect(tester, meadowPopoverKey);
      expect(times.left, 12);
      expect(times.right, _phone.width - 12);
      expect(times.bottom, dock.bottom - 56);
      expect(find.text('time of day'), findsOneWidget);
      for (final (String name, String sub) in <(String, String)>[
        ('Now', 'live'),
        ('Morning', '8 am'),
        ('Afternoon', '2 pm'),
        ('Evening', '7 pm'),
        ('Night', '11 pm'),
      ]) {
        expect(
          find.descendant(
            of: find.byKey(meadowPopoverKey),
            matching: find.text(name),
          ),
          findsOneWidget,
        );
        final Finder row = find.ancestor(
          of: find.text(sub),
          matching: find.byType(MeadowTimeRow),
        );
        expect(tester.getSize(row).height, 48);
      }
      expect(find.text('your meadows'), findsNothing);

      await tester.tapAt(const Offset(192, 200));
      await _settle(tester);
      expect(find.byKey(meadowPopoverKey), findsNothing);

      await tester.tap(find.byKey(meadowDetailsButtonKey));
      await _settle(tester);
      final Rect sheet = _rect(tester, meadowDetailsSheetKey);
      expect(sheet.left, 0);
      expect(sheet.right, _phone.width);
      expect(sheet.bottom, _phone.height - _gestureBar);
      expect(sheet.height, lessThanOrEqualTo(_phone.height * 0.58 + 0.01));
      expect(
        tester
            .widget<ConstrainedBox>(find.byKey(meadowDetailsSheetKey))
            .constraints
            .maxHeight,
        closeTo(_phone.height * 0.58, 0.01),
      );
      expect(
        _fillOf(tester, find.byKey(meadowDetailsSheetKey))!.toARGB32(),
        FieldNotesColors.light.cardWarm.toARGB32(),
      );
      expect(find.text('Day by day'), findsOneWidget);
      expect(find.text('This year so far'), findsOneWidget);
      expect(find.text('Tap a month to find its flowers'), findsOneWidget);
      expect(_rect(tester, meadowDetailsCloseKey).size, const Size(44, 44));
      expect(
        tester.getTopLeft(find.text('Jan')).dy,
        tester.getTopLeft(find.text('Apr')).dy,
      );
      expect(
        tester.getTopLeft(find.text('May')).dy,
        greaterThan(tester.getTopLeft(find.text('Jan')).dy),
      );

      await tester.tap(find.text('This year so far'));
      await _settle(tester);
      expect(find.text('Tap one to find those days'), findsOneWidget);
      expect(find.text('the weather'), findsOneWidget);

      await tester.tap(find.byKey(meadowDetailsCloseKey));
      await _settle(tester);
      expect(find.byKey(meadowDetailsSheetKey), findsNothing);
    },
  );

  testWidgets('a drag that starts on the phone dock does not pan the meadow', (
    WidgetTester tester,
  ) async {
    await _pumpGarden(tester);
    final MeadowStageState state = await _grow(tester);
    final double start = state.debugViewport!.pan;

    expect(find.text(meadowStageHint), findsOneWidget);
    final Rect hint = tester.getRect(
      find
          .ancestor(
            of: find.text(meadowStageHint),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect(hint.bottom, _dockBottom - 60);

    for (final Key key in <Key>[
      meadowTimeButtonKey,
      meadowYearPickerButtonKey,
      meadowDetailsButtonKey,
    ]) {
      await tester.dragFrom(
        tester.getCenter(find.byKey(key)),
        const Offset(-150, 0),
      );
      await tester.pump();
      expect(state.debugViewport!.pan, start, reason: '$key');
    }
    await tester.dragFrom(
      tester.getCenter(find.byKey(meadowDockKey)) + const Offset(0, 23),
      const Offset(150, 0),
    );
    await tester.pump();
    expect(state.debugViewport!.pan, start);
    expect(find.byKey(meadowPopoverKey), findsNothing);
    expect(find.byKey(meadowDetailsSheetKey), findsNothing);

    await tester.dragFrom(const Offset(192, 420), const Offset(-150, 0));
    await tester.pump();
    final double panned = state.debugViewport!.pan;
    expect(panned, greaterThan(start));
    expect(find.text(meadowStageHint), findsNothing);

    final MeadowStage stage = _stage(tester);
    final MeadowTerrain terrain = buildMeadowTerrain(
      seed: stage.seed,
      year: stage.year,
    );
    final Rect open = Rect.fromLTRB(
      24,
      _headerBottom + 140,
      _phone.width - 24,
      _dockBottom - 160,
    );
    final Offset head =
        buildMeadowPlants(seed: stage.seed, year: stage.year, terrain: terrain)
            .plants
            .where((MeadowPlant plant) => !plant.hidden)
            .map(
              (MeadowPlant plant) =>
                  state.debugViewport!.toLocal(plant.heads.last),
            )
            .firstWhere(open.contains);
    await tester.tapAt(head);
    await tester.pump();
    expect(state.debugViewport!.pan, panned);
    expect(find.byType(MeadowGlassTip), findsOneWidget);
    final Rect tip = tester.getRect(find.byType(MeadowGlassTip));
    expect(tip.left, 12);
    expect(tip.right, _phone.width - 12);
    expect(tip.bottom, _dockBottom - 60);
  });
  testWidgets(
    'the Meadow dock buttons blur from one shared backdrop of their own, '
    'after all their shadows',
    (WidgetTester tester) async {
      final ProviderContainer container = await _pumpShellMeadow(tester);
      final BackdropKey? shell = tester
          .renderObject<RenderBackdropFilter>(
            find.descendant(
              of: find.byKey(const ValueKey<String>('phone-header-glass')),
              matching: find.byType(BackdropFilter),
            ),
          )
          .backdropKey;
      expect(shell, isNotNull);
      expect(find.byKey(meadowReplayKey), findsNothing);
      _expectGroupedDock(tester, shell: shell!, glassButtons: 4);

      container
          .read(meadowViewStateProvider.notifier)
          .openYear(2025, currentYear: 2026);
      await _settle(tester);
      expect(
        find.descendant(
          of: find.byKey(meadowDockKey),
          matching: find.byKey(meadowReplayKey),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(meadowDockKey),
          matching: find.byKey(meadowThisYearButtonKey),
        ),
        findsOneWidget,
      );
      _expectGroupedDock(tester, shell: shell, glassButtons: 4);
    },
  );
}

MeadowStage _stage(WidgetTester tester) =>
    tester.widget<MeadowStage>(find.byType(MeadowStage));
