import 'package:field_notes/design/glass/glass.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/core/capture_date.dart';
import 'package:field_notes/features/garden/garden.dart';
import 'package:field_notes/features/garden/model/meadow_key_provider.dart';
import 'package:field_notes/features/garden/model/meadow_view_state.dart';
import 'package:field_notes/features/garden/scene/meadow_stage.dart';
import 'package:field_notes/features/garden/scene/meadow_view.dart';
import 'package:field_notes/features/garden/sky/sky_location.dart';
import 'package:field_notes/features/garden/sky/sky_location_provider.dart';
import 'package:field_notes/features/garden/sky/sky_time.dart';
import 'package:field_notes/features/garden/widgets/meadow_desktop_page.dart';
import 'package:field_notes/features/garden/widgets/meadow_details_panel.dart';
import 'package:field_notes/features/garden/widgets/meadow_full_screen.dart';
import 'package:field_notes/features/garden/widgets/meadow_glass_popover.dart';
import 'package:field_notes/features/garden/widgets/meadow_header.dart';
import 'package:field_notes/features/garden/widgets/meadow_study_controls.dart';
import 'package:field_notes/features/garden/widgets/meadow_tabs.dart';
import 'package:field_notes/features/garden/widgets/meadow_year_picker.dart';
import 'package:field_notes/features/streak/journaled_dates_provider.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/garden_harness.dart';

const Size _window = Size(1140, 820);
const int _buildFrames = 6000;
const Duration _frame = Duration(milliseconds: 16);

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

Future<ProviderContainer> _pump(WidgetTester tester) async {
  tester.view.physicalSize = _window;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
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

double _fade(WidgetTester tester, Key key) => tester
    .widget<FadeTransition>(
      find.descendant(
        of: find.byKey(key),
        matching: find.byType(FadeTransition),
      ),
    )
    .opacity
    .value;

MeadowStage _stage(WidgetTester tester) =>
    tester.widget<MeadowStage>(find.byType(MeadowStage));

void main() {
  testWidgets('the macOS meadow is full-bleed with a bottom glass dock', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await _pump(tester);

    expect(tester.getRect(find.byType(MeadowStage)), Offset.zero & _window);
    expect(_stage(tester).covers, isTrue);
    expect(_stage(tester).compact, isFalse);
    expect(tester.getTopLeft(find.text('your meadow')), const Offset(26, 22));
    expect(tester.widget<Text>(find.byKey(meadowTitleKey)).style!.fontSize, 34);
    expect(
      find.textContaining('· quietly filling in as the year goes'),
      findsOneWidget,
    );

    final Rect dock = _rect(tester, meadowDockKey);
    expect(dock.center.dx, closeTo(_window.width / 2, 0.5));
    expect(dock.bottom, _window.height - 20);
    final GlassSurface glass = tester.widget<GlassSurface>(
      find.byKey(meadowDockKey),
    );
    expect(glass.tone, GlassTone.scene);
    expect(glass.borderRadius, const BorderRadius.all(Radius.circular(26)));
    final List<Rect> items = <Rect>[
      _rect(tester, meadowYearPickerButtonKey),
      tester.getRect(find.byType(GardenSkyClock)),
      _rect(tester, meadowTimeButtonKey),
      _rect(tester, meadowDetailsButtonKey),
      _rect(tester, meadowFullScreenButtonKey),
    ];
    for (int index = 1; index < items.length; index++) {
      expect(items[index].left, greaterThan(items[index - 1].right));
    }
    expect(items[0].height, 40);
    expect(items[2].height, 40);
    expect(items[3].size, const Size(40, 40));
    expect(items[4].size, const Size(40, 40));
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
    expect(find.byTooltip('Your meadows, year by year (← →)'), findsOneWidget);
    expect(find.byTooltip('The year, day by day (D)'), findsOneWidget);
    expect(find.byTooltip('Full screen (F)'), findsOneWidget);
    expect(find.textContaining('sunset'), findsOneWidget);
    expect(find.byKey(meadowStudyPanelKey), findsNothing);
    expect(find.text(meadowPlayTheDayLabel), findsNothing);

    container
        .read(meadowViewStateProvider.notifier)
        .openYear(2025, currentYear: 2026);
    await _settle(tester);
    expect(find.text(meadowBackLabel), findsOneWidget);
    expect(find.text('meadow study'), findsOneWidget);
    expect(find.text('Your meadow, 2025'), findsOneWidget);
    expect(find.byType(GardenSkyClock), findsNothing);
    expect(find.byKey(meadowTimeButtonKey), findsNothing);
    final List<Rect> study = <Rect>[
      _rect(tester, meadowYearPickerButtonKey),
      _rect(tester, meadowStudyPlayKey),
      _rect(tester, meadowReplayKey),
      _rect(tester, meadowDetailsButtonKey),
      _rect(tester, meadowFullScreenButtonKey),
    ];
    for (int index = 1; index < study.length; index++) {
      expect(study[index].left, greaterThan(study[index - 1].right));
    }
    expect(find.text(meadowPlayTheDayLabel), findsOneWidget);
    expect(find.text(meadowReplayLabel), findsOneWidget);
    final Rect panel = _rect(tester, meadowStudyPanelKey);
    expect(panel.width, 520);
    expect(panel.center.dx, closeTo(_window.width / 2, 0.5));
    expect(panel.bottom, _window.height - 82);
    expect(find.text('Time of day'), findsOneWidget);
    expect(find.text('Grown through'), findsOneWidget);
    expect(_rect(tester, meadowHourSliderKey).height, 22);

    await tester.tap(find.text(meadowBackLabel));
    await _settle(tester);
    expect(container.read(meadowViewStateProvider).studyYear, isNull);

    await _grow(tester);
    expect(_fade(tester, meadowDockFadeKey), 1);
    expect(_fade(tester, meadowTitleFadeKey), 1);
    final TestGesture drag = await tester.startGesture(
      Offset(_window.width / 2, _window.height / 2),
      kind: PointerDeviceKind.mouse,
    );
    await drag.moveBy(const Offset(-30, 0));
    await tester.pump();
    await drag.moveBy(const Offset(-60, 0));
    await tester.pump();
    await tester.pump(meadowDeskChromeFade + _frame);
    expect(_fade(tester, meadowDockFadeKey), 0);
    expect(_fade(tester, meadowTitleFadeKey), 0);
    await drag.up();
    await tester.pump();
    await tester.pump(meadowDeskChromeFade + _frame);
    expect(_fade(tester, meadowDockFadeKey), 1);
    expect(_fade(tester, meadowTitleFadeKey), 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'macOS details open as a right-hand panel and the dock re-centres',
    (WidgetTester tester) async {
      await _pump(tester);
      final Rect before = _rect(tester, meadowDockKey);
      final Rect titleBefore = _rect(tester, meadowTitleBlockKey);
      expect(find.byKey(meadowDetailsPanelKey), findsNothing);

      await tester.tap(find.byKey(meadowDetailsButtonKey));
      await tester.pump();
      await tester.pump(meadowDetailsPanelSlide + _frame);
      await tester.pump(const Duration(milliseconds: 100));
      final Rect panel = _rect(tester, meadowDetailsPanelKey);
      expect(panel.width, 380);
      expect(panel.right, _window.width - 12);
      expect(panel.top, 12);
      expect(panel.bottom, _window.height - 12);

      final Rect after = _rect(tester, meadowDockKey);
      expect(
        after.center.dx,
        closeTo((_window.width - meadowDetailsPanelReserve) / 2, 0.5),
      );
      expect(
        before.center.dx - after.center.dx,
        closeTo(meadowDetailsPanelReserve / 2, 0.5),
      );
      expect(after.right, lessThan(panel.left));
      final Rect titleAfter = _rect(tester, meadowTitleBlockKey);
      expect(titleAfter.left, titleBefore.left);
      expect(
        titleAfter.right,
        closeTo(_window.width - 26 - meadowDetailsPanelReserve, 0.5),
      );

      expect(find.text('The year, day by day'), findsOneWidget);
      expect(find.text('This year so far'), findsOneWidget);
      expect(find.byTooltip('Close (Esc)'), findsOneWidget);
      expect(_rect(tester, meadowDetailsCloseKey).size, const Size(34, 34));
      expect(find.text('Hover a month to find its flowers'), findsOneWidget);
      expect(find.text(meadowDetailsKeysHint), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Jan')).dy,
        tester.getTopLeft(find.text('Apr')).dy,
      );
      expect(
        tester.getTopLeft(find.text('May')).dy,
        greaterThan(tester.getTopLeft(find.text('Apr')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Feb')).dx -
            tester
                .getTopRight(
                  find.ancestor(
                    of: find.text('Jan'),
                    matching: find.byType(AnimatedContainer),
                  ),
                )
                .dx,
        closeTo(8 + 6, 0.5),
      );
      expect(find.textContaining('Happy'), findsWidgets);

      await tester.tap(find.text('This year so far'));
      await _settle(tester);
      expect(
        find.text('Hover one to find those days in the meadow'),
        findsOneWidget,
      );
      expect(find.text('the weather'), findsOneWidget);

      await tester.tap(find.byKey(meadowDetailsCloseKey));
      await _settle(tester);
      expect(find.byKey(meadowDetailsPanelKey), findsNothing);
      expect(
        _rect(tester, meadowDockKey).center.dx,
        closeTo(_window.width / 2, 0.5),
      );

      await tester.tap(find.byKey(meadowYearPickerButtonKey));
      await _settle(tester);
      final Rect yearPill = _rect(tester, meadowYearPickerButtonKey);
      final Rect years = _rect(tester, meadowDropUpKey);
      expect(years.width, 300);
      expect(years.height, lessThanOrEqualTo(360));
      expect(years.bottom, closeTo(yearPill.top - 12, 0.5));
      expect(years.left, closeTo(yearPill.left - 6, 0.5));
      expect(find.text('your meadows'), findsOneWidget);
      expect(find.byKey(meadowYearRowKey(2025)), findsOneWidget);
      await tester.tapAt(const Offset(40, 400));
      await _settle(tester);
      expect(find.byKey(meadowDropUpKey), findsNothing);

      await tester.tap(find.byKey(meadowTimeButtonKey));
      await _settle(tester);
      final Rect timePill = _rect(tester, meadowTimeButtonKey);
      final Rect times = _rect(tester, meadowDropUpKey);
      expect(times.width, 200);
      expect(times.bottom, closeTo(timePill.top - 12, 0.5));
      expect(times.center.dx, closeTo(timePill.center.dx, 0.5));
      final Finder evening = find.ancestor(
        of: find.text('Evening'),
        matching: find.byType(MeadowTimeRow),
      );
      expect(tester.getSize(evening).height, 36);
      await tester.tap(evening);
      await _settle(tester);
      expect(find.byKey(meadowDropUpKey), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(meadowTimeButtonKey),
          matching: find.text('Evening'),
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('D, F, arrows and Esc drive the macOS meadow', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await _pump(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await _settle(tester);
    expect(find.byKey(meadowDetailsPanelKey), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await _settle(tester);
    expect(find.byKey(meadowDetailsPanelKey), findsNothing);

    await tester.tap(find.byKey(meadowYearPickerButtonKey));
    await _settle(tester);
    expect(find.byKey(meadowDropUpKey), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await _settle(tester);
    expect(find.byKey(meadowDropUpKey), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await _settle(tester);
    expect(container.read(meadowViewStateProvider).studyYear, 2025);
    expect(_stage(tester).year.year, 2025);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await _settle(tester);
    expect(_stage(tester).year.year, 2025);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await _settle(tester);
    expect(container.read(meadowViewStateProvider).studyYear, isNull);
    expect(_stage(tester).year.year, 2026);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await _settle(tester);
    expect(_stage(tester).year.year, 2026);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await _settle(tester);
    expect(find.byKey(meadowDetailsPanelKey), findsNothing);
    expect(container.read(meadowViewStateProvider).fullScreen, isNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.pump();
    await tester.pump(meadowFullScreenFade + _frame);
    expect(
      container.read(meadowViewStateProvider).fullScreen,
      isA<MeadowFullScreenRequest>(),
    );
    expect(find.byTooltip('Exit full screen (F)'), findsOneWidget);
    expect(_stage(tester).mode, MeadowSceneMode.full);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await _settle(tester);
    expect(find.byKey(meadowDetailsPanelKey), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await _settle(tester);
    expect(find.byKey(meadowDetailsPanelKey), findsNothing);
    expect(
      container.read(meadowViewStateProvider).fullScreen,
      isA<MeadowFullScreenRequest>(),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.pump();
    await tester.pump(meadowFullScreenFade + _frame);
    expect(container.read(meadowViewStateProvider).fullScreen, isNull);
    expect(find.byTooltip('Full screen (F)'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.pump();
    await tester.pump(meadowFullScreenFade + _frame);
    expect(find.byTooltip('Exit full screen (F)'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(meadowFullScreenFade + _frame);
    expect(container.read(meadowViewStateProvider).fullScreen, isNull);
    expect(_stage(tester).mode, MeadowSceneMode.page);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a drag that starts on the macOS dock does not pan the meadow', (
    WidgetTester tester,
  ) async {
    await _pump(tester);
    final MeadowStageState state = await _grow(tester);
    final double start = state.debugViewport!.pan;

    for (final Key key in <Key>[
      meadowTimeButtonKey,
      meadowYearPickerButtonKey,
      meadowDetailsButtonKey,
    ]) {
      await tester.dragFrom(
        tester.getCenter(find.byKey(key)),
        const Offset(-150, 0),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      expect(state.debugViewport!.pan, start, reason: '$key');
    }
    await tester.dragFrom(
      tester.getCenter(find.byType(GardenSkyClock)),
      const Offset(150, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    expect(state.debugViewport!.pan, start);
    expect(find.byKey(meadowDropUpKey), findsNothing);
    expect(find.byKey(meadowDetailsPanelKey), findsNothing);

    await tester.dragFrom(
      Offset(_window.width / 2, _window.height / 2),
      const Offset(-150, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    expect(state.debugViewport!.pan, greaterThan(start));
    await tester.pumpWidget(const SizedBox());
  });
}
