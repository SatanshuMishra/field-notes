import 'dart:async';

import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/app/shell/window_chrome.dart';
import 'package:field_notes/design/tokens/typography.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/core/capture_date.dart';
import 'package:field_notes/features/garden/model/meadow_random.dart';
import 'package:field_notes/features/garden/model/meadow_view_state.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/scene/meadow_stage.dart';
import 'package:field_notes/features/garden/scene/meadow_view.dart';
import 'package:field_notes/features/garden/sky/sky_astronomy.dart';
import 'package:field_notes/features/garden/sky/sky_location.dart';
import 'package:field_notes/features/garden/sky/sky_location_provider.dart';
import 'package:field_notes/features/garden/sky/sky_scene.dart';
import 'package:field_notes/features/garden/sky/sky_time.dart';
import 'package:field_notes/features/garden/widgets/meadow_full_screen.dart';
import 'package:field_notes/state/shell_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/garden_harness.dart';

const int _meadowKey = 20250630;
const int _buildFrames = 6000;
const Size _phoneScreen = Size(411.4, 868.6);
const Size _macWindow = Size(1100, 700);
const Key _pageKey = ValueKey<String>('meadow-page');
const Color _glassInk = Color(0xFFFBF3E4);
const Duration _frame = Duration(milliseconds: 16);

final DateTime _now = DateTime.utc(2025, 6, 30, 19);
final SkyLocation _edmonton = resolveSkyLocation(
  'America/Edmonton',
  const Duration(hours: -6),
);

MeadowYear _yearOf(int year, {required DateTime today}) => MeadowYear.build(
  days: <Day>[
    for (int day = 1; day <= 24; day++)
      dayOf(
        captureDateKey(DateTime(year, 3, day)),
        mood: moodOrder[day % moodOrder.length],
      ),
  ],
  entryCounts: <String, int>{captureDateKey(DateTime(year, 4, 2)): 2},
  year: year,
  today: today,
);

DateTime _todayAt(int minutes) {
  final DateTime local = _now.toLocal();
  return DateTime(
    local.year,
    local.month,
    local.day,
    minutes ~/ 60,
    minutes % 60,
  );
}

SkyScene _skyAt(DateTime instant) =>
    skySceneAt(instant, _edmonton.latitude, _edmonton.longitude);

bool _morningAt(DateTime instant) =>
    sunPosition(instant, _edmonton.latitude, _edmonton.longitude).azimuth < 0;

Future<ProviderContainer> _pumpPage(
  WidgetTester tester, {
  required Size size,
  required TargetPlatform platform,
  bool debugControls = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    gardenHarness(
      const SizedBox.expand(key: _pageKey),
      platform: platform,
      overrides: <Override>[
        skyClockProvider.overrideWithValue(() => _now),
        skyLocationProvider.overrideWith((_) async => _edmonton),
        skyDebugControlsProvider.overrideWithValue(debugControls),
      ],
    ),
  );
  await tester.pump();
  return ProviderScope.containerOf(
    tester.element(find.byKey(_pageKey)),
    listen: false,
  );
}

void _launch(
  WidgetTester tester,
  ProviderContainer container, {
  required MeadowFullScreenRequest request,
  required MeadowYear year,
  required bool compact,
  required bool isCurrentYear,
}) {
  container.read(meadowViewStateProvider.notifier).openFullScreen(request);
  unawaited(
    openMeadowFullScreen(
      tester.element(find.byKey(_pageKey)),
      request: request,
      year: year,
      seed: meadowSeed(_meadowKey, year.year),
      compact: compact,
      isCurrentYear: isCurrentYear,
    ),
  );
}

Future<void> _open(
  WidgetTester tester,
  ProviderContainer container, {
  required MeadowFullScreenRequest request,
  required MeadowYear year,
  required bool compact,
  required bool isCurrentYear,
}) async {
  _launch(
    tester,
    container,
    request: request,
    year: year,
    compact: compact,
    isCurrentYear: isCurrentYear,
  );
  await tester.pump();
  await tester.pump(meadowFullScreenFade + _frame);
}

Future<void> _settleClose(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(meadowFullScreenFade + _frame);
}

Future<void> _grow(WidgetTester tester) async {
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
}

MeadowStage _stage(WidgetTester tester) =>
    tester.widget<MeadowStage>(find.byType(MeadowStage));

double _routeOpacity(WidgetTester tester) => tester
    .widget<FadeTransition>(
      find
          .ancestor(
            of: find.byType(MeadowStage),
            matching: find.byType(FadeTransition),
          )
          .first,
    )
    .opacity
    .value;

void main() {
  testWidgets('on the sidebar layout the full-screen title starts clear of the '
      'window buttons', (WidgetTester tester) async {
    final MeadowYear year = _yearOf(2025, today: DateTime(2025, 6, 30));
    final MeadowFullScreenRequest request = MeadowFullScreenRequest(
      year: 2025,
      hourMinutes: null,
      growthPoint: year.limit,
    );

    final ProviderContainer mac = await _pumpPage(
      tester,
      size: _macWindow,
      platform: TargetPlatform.macOS,
    );
    await _open(
      tester,
      mac,
      request: request,
      year: year,
      compact: false,
      isCurrentYear: true,
    );
    expect(
      tester.getRect(find.byKey(meadowFullScreenTitleKey)).left,
      greaterThanOrEqualTo(windowButtonsClearance),
    );
    await tester.tap(find.byKey(meadowFullScreenCloseKey));
    await _settleClose(tester);

    final ProviderContainer phone = await _pumpPage(
      tester,
      size: _phoneScreen,
      platform: TargetPlatform.android,
    );
    await _open(
      tester,
      phone,
      request: request,
      year: year,
      compact: true,
      isCurrentYear: true,
    );
    expect(tester.getRect(find.byKey(meadowFullScreenTitleKey)).left, 14);
  });

  testWidgets("full screen opens with the page's year and growth point", (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await _pumpPage(
      tester,
      size: _macWindow,
      platform: TargetPlatform.macOS,
    );
    final MeadowYear past = _yearOf(2024, today: DateTime(2025, 6, 30));
    const MeadowFullScreenRequest study = MeadowFullScreenRequest(
      year: 2024,
      hourMinutes: 7 * 60,
      growthPoint: 200,
    );
    container
        .read(meadowViewStateProvider.notifier)
        .openYear(2024, currentYear: 2025);

    _launch(
      tester,
      container,
      request: study,
      year: past,
      compact: false,
      isCurrentYear: false,
    );
    await tester.pump();
    await tester.pump(
      Duration(microseconds: meadowFullScreenFade.inMicroseconds ~/ 2),
    );
    expect(_routeOpacity(tester), closeTo(0.5, 0.01));
    await tester.pump(meadowFullScreenFade);
    expect(_routeOpacity(tester), 1);
    expect(
      ModalRoute.of(tester.element(find.byType(MeadowStage)))!.opaque,
      isTrue,
    );

    final MeadowStage stage = _stage(tester);
    expect(stage.year, same(past));
    expect(stage.year.year, 2024);
    expect(stage.growthPoint, 200);
    expect(stage.seed, meadowSeed(_meadowKey, 2024));
    expect(stage.mode, MeadowSceneMode.full);
    expect(stage.compact, isFalse);
    expect(stage.covers, isTrue);
    final DateTime seven = _todayAt(7 * 60);
    expect(stage.sky.sunAltitude, _skyAt(seven).sunAltitude);
    expect(stage.sky.moonAltitude, _skyAt(seven).moonAltitude);
    expect(stage.morning, _morningAt(seven));
    expect(tester.getRect(find.byType(MeadowStage)), Offset.zero & _macWindow);

    expect(find.text('Meadow study · 2024'), findsOneWidget);
    final TextStyle label = tester
        .widget<Text>(find.text('Meadow study · 2024'))
        .style!;
    expect(label.fontFamily, TypographyTokens.accent);
    expect(label.fontSize, 22);
    expect(label.color, _glassInk);
    expect(find.byKey(meadowFullScreenPlayKey), findsNothing);
    expect(find.text('Play the day'), findsNothing);
    expect(
      tester.getSize(find.byKey(meadowFullScreenCloseKey)),
      const Size(48, 48),
    );
    expect(
      tester.getTopRight(find.byKey(meadowFullScreenCloseKey)),
      Offset(_macWindow.width - 11, 9),
    );

    await tester.tap(find.byKey(meadowFullScreenCloseKey));
    await _settleClose(tester);

    final MeadowYear current = _yearOf(2025, today: DateTime(2025, 6, 30));
    final MeadowFullScreenRequest live = MeadowFullScreenRequest(
      year: 2025,
      hourMinutes: null,
      growthPoint: current.limit,
    );
    container.read(meadowViewStateProvider.notifier).backToThisYear();
    await _open(
      tester,
      container,
      request: live,
      year: current,
      compact: false,
      isCurrentYear: true,
    );
    expect(_stage(tester).growthPoint, current.limit);
    expect(_stage(tester).sky.sunAltitude, _skyAt(_now).sunAltitude);
    expect(_stage(tester).morning, _morningAt(_now));
    expect(find.text('Your meadow · 2025 · still growing'), findsOneWidget);

    await tester.tap(find.byKey(meadowFullScreenCloseKey));
    await _settleClose(tester);
    await _open(
      tester,
      container,
      request: MeadowFullScreenRequest(
        year: 2025,
        hourMinutes: null,
        growthPoint: current.daysInYear,
      ),
      year: current,
      compact: false,
      isCurrentYear: true,
    );
    expect(find.text('Your meadow · 2025'), findsOneWidget);

    await tester.tap(find.byKey(meadowFullScreenCloseKey));
    await _settleClose(tester);
    await _open(
      tester,
      container,
      request: live,
      year: current,
      compact: true,
      isCurrentYear: true,
    );
    expect(find.text('2025'), findsOneWidget);
    expect(_stage(tester).compact, isTrue);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the close button, escape and back leave full screen', (
    WidgetTester tester,
  ) async {
    for (final (TargetPlatform platform, Size size, bool compact)
        in <(TargetPlatform, Size, bool)>[
          (TargetPlatform.macOS, _macWindow, false),
          (TargetPlatform.android, _phoneScreen, true),
        ]) {
      final ProviderContainer container = await _pumpPage(
        tester,
        size: size,
        platform: platform,
      );
      final MeadowYear past = _yearOf(2024, today: DateTime(2025, 6, 30));
      const MeadowFullScreenRequest request = MeadowFullScreenRequest(
        year: 2024,
        hourMinutes: null,
        growthPoint: 200,
      );
      final MeadowViewState view = container.read(
        meadowViewStateProvider.notifier,
      );
      container
          .read(shellNavigationProvider.notifier)
          .select(ShellDestination.garden);
      view.openYear(2024, currentYear: 2025);

      for (final (String way, Future<void> Function() leave)
          in <(String, Future<void> Function())>[
            (
              'close button',
              () => tester.tap(find.byKey(meadowFullScreenCloseKey)),
            ),
            ('escape', () => tester.sendKeyEvent(LogicalKeyboardKey.escape)),
            ('back', () => tester.binding.handlePopRoute()),
          ]) {
        await _open(
          tester,
          container,
          request: request,
          year: past,
          compact: compact,
          isCurrentYear: false,
        );
        expect(find.byType(MeadowStage), findsOneWidget, reason: way);
        expect(container.read(meadowViewStateProvider).fullScreen, request);

        await leave();
        await _settleClose(tester);

        expect(
          find.byType(MeadowStage),
          findsNothing,
          reason: '$way $platform',
        );
        expect(find.byKey(_pageKey), findsOneWidget, reason: way);
        expect(
          container.read(meadowViewStateProvider),
          const MeadowView(studyYear: 2024),
          reason: '$way $platform',
        );
      }
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('leaving the tab closes full screen', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await _pumpPage(
      tester,
      size: _macWindow,
      platform: TargetPlatform.macOS,
    );
    final MeadowYear current = _yearOf(2025, today: DateTime(2025, 6, 30));
    container
        .read(shellNavigationProvider.notifier)
        .select(ShellDestination.garden);
    await _open(
      tester,
      container,
      request: MeadowFullScreenRequest(
        year: 2025,
        hourMinutes: null,
        growthPoint: current.limit,
      ),
      year: current,
      compact: false,
      isCurrentYear: true,
    );
    expect(find.byType(MeadowStage), findsOneWidget);

    container
        .read(shellNavigationProvider.notifier)
        .select(ShellDestination.today);
    await _settleClose(tester);

    expect(find.byType(MeadowStage), findsNothing);
    expect(container.read(meadowViewStateProvider), const MeadowView());

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the phone shows the drag hint until the first drag or tap', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final ProviderContainer container = await _pumpPage(
      tester,
      size: _phoneScreen,
      platform: TargetPlatform.android,
    );
    final MeadowYear current = _yearOf(2025, today: DateTime(2025, 6, 30));
    final MeadowFullScreenRequest request = MeadowFullScreenRequest(
      year: 2025,
      hourMinutes: null,
      growthPoint: current.limit,
    );

    for (final (String first, Future<void> Function() interact)
        in <(String, Future<void> Function())>[
          (
            'drag',
            () => tester.drag(find.byType(MeadowStage), const Offset(-120, 0)),
          ),
          ('tap', () => tester.tap(find.byType(MeadowStage))),
        ]) {
      await _open(
        tester,
        container,
        request: request,
        year: current,
        compact: true,
        isCurrentYear: true,
      );
      await _grow(tester);
      await tester.pump();

      expect(find.text(meadowStageHint), findsOneWidget, reason: first);
      final Rect hint = tester.getRect(
        find
            .ancestor(
              of: find.text(meadowStageHint),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(hint.center.dx, closeTo(_phoneScreen.width / 2, 0.5));
      expect(hint.bottom, closeTo(_phoneScreen.height - 18, 0.5));

      await tester.pump(const Duration(seconds: 1));
      expect(find.text(meadowStageHint), findsOneWidget, reason: first);

      await interact();
      await tester.pump();
      expect(find.text(meadowStageHint), findsNothing, reason: first);

      await tester.tap(find.byKey(meadowFullScreenCloseKey));
      await _settleClose(tester);
      expect(find.byType(MeadowStage), findsNothing);
    }

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    "play the day runs the full screen's own hour only in debug builds",
    (WidgetTester tester) async {
      final ProviderContainer container = await _pumpPage(
        tester,
        size: _macWindow,
        platform: TargetPlatform.macOS,
        debugControls: true,
      );
      final MeadowYear past = _yearOf(2024, today: DateTime(2025, 6, 30));
      await _open(
        tester,
        container,
        request: const MeadowFullScreenRequest(
          year: 2024,
          hourMinutes: 6 * 60,
          growthPoint: 200,
        ),
        year: past,
        compact: false,
        isCurrentYear: false,
      );
      expect(_stage(tester).sky.sunAltitude, _skyAt(_todayAt(360)).sunAltitude);
      expect(find.text('Play the day'), findsOneWidget);
      expect(tester.getSize(find.byKey(meadowFullScreenPlayKey)).height, 48);

      await tester.tap(find.byKey(meadowFullScreenPlayKey));
      await tester.pump();
      expect(find.text('Pause'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
      expect(_stage(tester).sky.sunAltitude, _skyAt(_todayAt(390)).sunAltitude);
      expect(_stage(tester).morning, _morningAt(_todayAt(390)));
      expect(container.read(skyTimeProvider).offset, Duration.zero);

      await tester.tap(find.byKey(meadowFullScreenPlayKey));
      await tester.pump();
      expect(find.text('Play the day'), findsOneWidget);
      final double paused = _stage(tester).sky.sunAltitude;
      await tester.pump(const Duration(milliseconds: 500));
      expect(_stage(tester).sky.sunAltitude, paused);

      await tester.tap(find.byKey(meadowFullScreenCloseKey));
      await _settleClose(tester);
      expect(container.read(meadowViewStateProvider).fullScreen, isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
