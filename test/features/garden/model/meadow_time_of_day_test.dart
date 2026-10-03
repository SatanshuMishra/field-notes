import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/garden/garden.dart';
import 'package:field_notes/features/garden/model/meadow_key_provider.dart';
import 'package:field_notes/features/garden/model/meadow_time_of_day.dart';
import 'package:field_notes/features/garden/model/meadow_view_state.dart';
import 'package:field_notes/features/garden/scene/meadow_stage.dart';
import 'package:field_notes/features/garden/sky/sky_location.dart';
import 'package:field_notes/features/garden/sky/sky_location_provider.dart';
import 'package:field_notes/features/garden/sky/sky_scene.dart';
import 'package:field_notes/features/garden/sky/sky_time.dart';
import 'package:field_notes/features/garden/widgets/meadow_full_screen.dart';
import 'package:field_notes/features/garden/widgets/meadow_header.dart';
import 'package:field_notes/features/garden/widgets/meadow_study_controls.dart';
import 'package:field_notes/features/streak/journaled_dates_provider.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/garden_harness.dart';

const Size _phone = Size(384, 832);
const Size _desk = Size(1140, 820);
const Duration _frame = Duration(milliseconds: 16);

final DateTime _noon = DateTime.utc(2026, 9, 28, 18);
final SkyLocation _edmonton = resolveSkyLocation(
  'America/Edmonton',
  const Duration(hours: -6),
);

final List<Day> _days = <Day>[
  dayOf('2025-05-02', mood: Mood.calm),
  dayOf('2025-05-03', mood: Mood.happy),
  dayOf('2026-03-01', mood: Mood.happy),
  dayOf('2026-03-02', mood: Mood.warm),
];

SkyScene _skyAt(DateTime instant) =>
    skySceneAt(instant, _edmonton.latitude, _edmonton.longitude);

Future<ProviderContainer> _pumpGarden(
  WidgetTester tester, {
  required TargetPlatform platform,
  required Size size,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  if (platform == TargetPlatform.android) {
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

MeadowStage _stage(WidgetTester tester) =>
    tester.widget<MeadowStage>(find.byType(MeadowStage));

Finder _timeButtonText(String label) => find.descendant(
  of: find.byKey(meadowTimeButtonKey),
  matching: find.text(label),
);

Future<void> _choose(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(meadowTimeButtonKey));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.text(label).last);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets(
    'the time of day presets set the sky hour and Now returns to live',
    (WidgetTester tester) async {
      expect(
        meadowTimesOfDay.map((MeadowTimeOfDay time) => time.label),
        <String>['Now', 'Morning', 'Afternoon', 'Evening', 'Night'],
      );
      expect(meadowTimesOfDay.map((MeadowTimeOfDay time) => time.sub), <String>[
        'live',
        '8 am',
        '2 pm',
        '7 pm',
        '11 pm',
      ]);
      expect(
        meadowTimesOfDay.map((MeadowTimeOfDay time) => time.minutes),
        <int?>[null, 8 * 60, 14 * 60, 19 * 60, 23 * 60],
      );
      expect(meadowTimeOfDayAt(null), meadowTimeNow);
      expect(meadowTimeOfDayAt(19 * 60), meadowTimeEvening);
      expect(meadowTimeOfDayAt(15 * 60 + 30), isNull);
      expect(meadowTimeOfDayLabel(19 * 60), 'Evening');
      expect(meadowTimeOfDayLabel(null), 'Now');
      expect(meadowTimeOfDayLabel(15 * 60 + 30), 'Custom');

      final ProviderContainer container = await _pumpGarden(
        tester,
        platform: TargetPlatform.android,
        size: _phone,
      );
      expect(_timeButtonText('Now'), findsOneWidget);
      expect(_stage(tester).sky, _skyAt(_noon));

      await _choose(tester, 'Evening');
      expect(find.text('7 pm'), findsNothing);
      expect(_timeButtonText('Evening'), findsOneWidget);
      expect(_stage(tester).sky, _skyAt(meadowTodayAt(_noon, 19 * 60)));
      expect(_stage(tester).sky, isNot(_skyAt(_noon)));

      container.read(skyTimeProvider.notifier).toggleFastForward();
      await tester.pump(const Duration(seconds: 1));
      expect(container.read(skyTimeProvider).fastForwarding, isTrue);
      expect(container.read(skyTimeProvider).shifted, isTrue);
      expect(_stage(tester).sky, _skyAt(meadowTodayAt(_noon, 19 * 60)));

      await _choose(tester, 'Night');
      expect(container.read(skyTimeProvider).fastForwarding, isFalse);
      expect(_timeButtonText('Night'), findsOneWidget);
      expect(_stage(tester).sky, _skyAt(meadowTodayAt(_noon, 23 * 60)));

      await _choose(tester, 'Now');
      expect(container.read(skyTimeProvider).offset, Duration.zero);
      expect(container.read(skyTimeProvider).instant, _noon);
      expect(_timeButtonText('Now'), findsOneWidget);
      expect(_stage(tester).sky, _skyAt(_noon));

      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('the meadow shows its time controls without debug mode', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = _desk;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final List<String> pressed = <String>[];
    Future<void> clock(SkyMoment moment) => tester.pumpWidget(
      MaterialApp(
        theme: fieldNotesTheme(platform: TargetPlatform.macOS),
        home: Scaffold(
          body: Center(
            child: GardenSkyClock(
              moment: moment,
              onNow: () => pressed.add('now'),
              onFastForward: () => pressed.add('play'),
            ),
          ),
        ),
      ),
    );

    await clock(SkyMoment(instant: _noon));
    expect(find.text(meadowPlayTheDayLabel), findsOneWidget);
    expect(find.text(meadowNowLabel), findsNothing);
    await tester.tap(find.text(meadowPlayTheDayLabel));
    expect(pressed, <String>['play']);

    await clock(
      SkyMoment(
        instant: _noon.add(const Duration(hours: 2)),
        offset: const Duration(hours: 2),
        fastForwarding: true,
      ),
    );
    expect(find.text(meadowPauseLabel), findsOneWidget);
    expect(find.text(meadowNowLabel), findsOneWidget);
    await tester.tap(find.text(meadowNowLabel));
    expect(pressed, <String>['play', 'now']);

    final ProviderContainer container = await _pumpGarden(
      tester,
      platform: TargetPlatform.macOS,
      size: _desk,
    );
    container
        .read(meadowViewStateProvider.notifier)
        .openYear(2025, currentYear: 2026);
    await tester.pump();
    expect(find.byType(MeadowStudyControls), findsOneWidget);
    expect(find.byKey(meadowStudyPlayKey), findsOneWidget);
    expect(find.text(meadowPlayTheDayLabel), findsOneWidget);
    await tester.tap(find.byKey(meadowStudyPlayKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(meadowPauseLabel), findsOneWidget);
    await tester.tap(find.byKey(meadowStudyPlayKey));
    await tester.pump();
    expect(find.text(meadowPlayTheDayLabel), findsOneWidget);
    await tester.pumpWidget(const SizedBox());

    await _pumpGarden(tester, platform: TargetPlatform.android, size: _phone);
    await tester.tap(find.byKey(meadowFullScreenButtonKey));
    await tester.pump();
    await tester.pump(meadowFullScreenFade + _frame);
    expect(find.byKey(meadowFullScreenPlayKey), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(meadowFullScreenPlayKey),
        matching: find.text(meadowPlayTheDayLabel),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(meadowFullScreenPlayKey));
    await tester.pump();
    expect(
      find.descendant(
        of: find.byKey(meadowFullScreenPlayKey),
        matching: find.text(meadowPauseLabel),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(meadowFullScreenCloseKey));
    await tester.pump();
    await tester.pump(meadowFullScreenFade + _frame);
    expect(find.byKey(meadowFullScreenPlayKey), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
