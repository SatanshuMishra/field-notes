import 'package:field_notes/design/format/clock_format.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/garden/garden.dart';
import 'package:field_notes/features/garden/model/meadow_key_provider.dart';
import 'package:field_notes/features/garden/scene/meadow_stage.dart';
import 'package:field_notes/features/garden/sky/sky_location.dart';
import 'package:field_notes/features/garden/sky/sky_location_provider.dart';
import 'package:field_notes/features/garden/sky/sky_scene.dart';
import 'package:field_notes/features/garden/sky/sky_time.dart';
import 'package:field_notes/features/garden/widgets/meadow_header.dart';
import 'package:field_notes/features/streak/journaled_dates_provider.dart';
import 'package:field_notes/features/today/today_date.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/garden_harness.dart';

final DateTime _start = DateTime.utc(2026, 9, 28, 18);
const Duration _edmontonOffset = Duration(hours: -6);
final SkyLocation _edmonton = resolveSkyLocation(
  'America/Edmonton',
  _edmontonOffset,
);

const List<AppLifecycleState> _toPaused = <AppLifecycleState>[
  AppLifecycleState.inactive,
  AppLifecycleState.hidden,
  AppLifecycleState.paused,
];

const List<AppLifecycleState> _toResumed = <AppLifecycleState>[
  AppLifecycleState.hidden,
  AppLifecycleState.inactive,
  AppLifecycleState.resumed,
];

const List<String> _weekdays = <String>[
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

class _SkyHarness {
  _SkyHarness(this.now);

  DateTime now;
  String zone = 'America/Edmonton';
  final ValueNotifier<bool> shown = ValueNotifier<bool>(true);
  final ValueNotifier<bool> mounted = ValueNotifier<bool>(true);
}

Future<_SkyHarness> _pumpGarden(
  WidgetTester tester, {
  bool overrideLocation = true,
}) async {
  final _SkyHarness sky = _SkyHarness(_start);
  addTearDown(sky.shown.dispose);
  addTearDown(sky.mounted.dispose);
  tester.view.physicalSize = const Size(1140, 766);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    gardenHarness(
      ValueListenableBuilder<bool>(
        valueListenable: sky.mounted,
        builder: (BuildContext context, bool mounted, Widget? child) =>
            mounted ? child! : const SizedBox.shrink(),
        child: ValueListenableBuilder<bool>(
          valueListenable: sky.shown,
          builder: (BuildContext context, bool shown, Widget? child) =>
              TickerMode(enabled: shown, child: child!),
          child: const GardenScreen(),
        ),
      ),
      platform: TargetPlatform.macOS,
      overrides: <Override>[
        allDaysProvider.overrideWith(
          (_) => Stream<List<Day>>.value(<Day>[
            dayOf('2026-03-01', mood: Mood.happy),
            dayOf('2026-03-02', mood: Mood.calm),
          ]),
        ),
        journalEntryCountsProvider.overrideWith(
          (_) => Stream<Map<String, int>>.value(const <String, int>{}),
        ),
        meadowKeyProvider.overrideWith((_) async => 24601),
        skyClockProvider.overrideWithValue(() => sky.now),
        localTimezoneIdentifierProvider.overrideWith((_) async => sky.zone),
        localUtcOffsetProvider.overrideWith((_) => _edmontonOffset),
        if (overrideLocation)
          skyLocationProvider.overrideWith((_) async => _edmonton),
      ],
    ),
  );
  await tester.pump();
  await tester.pump();
  return sky;
}

Future<void> _lifecycle(
  WidgetTester tester,
  List<AppLifecycleState> states,
) async {
  for (final AppLifecycleState state in states) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  await tester.pump();
}

SkyScene _painted(WidgetTester tester) =>
    tester.widget<MeadowStage>(find.byType(MeadowStage)).sky;

SkyScene _sceneAt(DateTime instant) =>
    skySceneAt(instant, _edmonton.latitude, _edmonton.longitude);

String _clock(WidgetTester tester, DateTime instant) => formatClock(
  tester.element(find.byType(GardenScreen)),
  TimeOfDay.fromDateTime(instant.toLocal()),
);

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

void main() {
  testWidgets(
    'the sky refreshes every minute while shown and at once on resume',
    (WidgetTester tester) async {
      final _SkyHarness sky = await _pumpGarden(tester);
      final SkyScene first = _painted(tester);
      expect(first, _sceneAt(_start));
      expect(find.text(_clock(tester, _start)), findsOneWidget);

      sky.now = _start.add(const Duration(seconds: 30));
      await tester.pump(const Duration(seconds: 30));
      expect(_painted(tester), first);

      sky.now = _start.add(const Duration(seconds: 60));
      await tester.pump(const Duration(seconds: 30));
      expect(_painted(tester), _sceneAt(sky.now));
      expect(_painted(tester), isNot(first));
      expect(find.text(_clock(tester, sky.now)), findsOneWidget);

      sky.now = _start.add(const Duration(minutes: 2));
      await tester.pump(const Duration(seconds: 60));
      expect(_painted(tester), _sceneAt(sky.now));

      await _lifecycle(tester, _toPaused);
      sky.now = _start.add(const Duration(minutes: 47, seconds: 13));
      await _lifecycle(tester, _toResumed);
      expect(_painted(tester), _sceneAt(sky.now));
      expect(find.text(_clock(tester, sky.now)), findsOneWidget);
    },
  );

  testWidgets('a paused app or a hidden garden stops the minute timer', (
    WidgetTester tester,
  ) async {
    final _SkyHarness sky = await _pumpGarden(tester);
    final ProviderContainer container = _container(tester);
    expect(container.read(skyTimeProvider).instant, _start);

    await _lifecycle(tester, _toPaused);
    sky.now = _start.add(const Duration(minutes: 5));
    await tester.pump(const Duration(minutes: 5));
    expect(container.read(skyTimeProvider).instant, _start);

    await _lifecycle(tester, _toResumed);
    expect(container.read(skyTimeProvider).instant, sky.now);
    expect(_painted(tester), _sceneAt(sky.now));

    final DateTime hiddenAt = sky.now;
    sky.shown.value = false;
    await tester.pump();
    sky.now = hiddenAt.add(const Duration(minutes: 5));
    await tester.pump(const Duration(minutes: 5));
    expect(container.read(skyTimeProvider).instant, hiddenAt);

    sky.shown.value = true;
    await tester.pump();
    await tester.pump();
    expect(container.read(skyTimeProvider).instant, sky.now);
    expect(_painted(tester), _sceneAt(sky.now));

    sky.mounted.value = false;
    await tester.pump();
    await tester.pump();
    expect(container.exists(skyTimeProvider), isFalse);
    await tester.pump(const Duration(minutes: 3));
    expect(container.exists(skyTimeProvider), isFalse);
  });

  testWidgets('resuming reads the time zone again', (
    WidgetTester tester,
  ) async {
    final _SkyHarness sky = await _pumpGarden(tester, overrideLocation: false);
    expect(_painted(tester), _sceneAt(sky.now));

    await _lifecycle(tester, _toPaused);
    sky.zone = 'Europe/London';
    await _lifecycle(tester, _toResumed);
    await tester.pump();
    await tester.pump();

    final SkyLocation london = resolveSkyLocation(
      'Europe/London',
      _edmontonOffset,
    );
    expect(
      _painted(tester),
      skySceneAt(sky.now, london.latitude, london.longitude),
    );
    expect(_painted(tester), isNot(_sceneAt(sky.now)));
  });

  testWidgets(
    'Play the day moves the painted sun 30 minutes a second and the time '
    "picker's Now returns",
    (WidgetTester tester) async {
      final _SkyHarness sky = await _pumpGarden(tester);
      final ProviderContainer container = _container(tester);
      final SkyScene before = _painted(tester);

      container.read(skyTimeProvider.notifier).toggleFastForward();
      await tester.pump();
      expect(container.read(skyTimeProvider).fastForwarding, isTrue);

      await tester.pump(const Duration(seconds: 3));
      final DateTime shifted = sky.now.add(const Duration(minutes: 90));
      final DateTime local = shifted.toLocal();
      expect(
        find.text(
          '${_weekdays[local.weekday - 1]} ${shortMonthDayLabel(shifted)} · '
          '${_clock(tester, shifted)}',
        ),
        findsOneWidget,
      );
      expect(_painted(tester), _sceneAt(shifted));
      expect(_painted(tester).sunX, isNot(before.sunX));
      expect(_painted(tester).sunY, isNot(before.sunY));

      container.read(skyTimeProvider.notifier).toggleFastForward();
      await tester.pump();
      expect(container.read(skyTimeProvider).fastForwarding, isFalse);
      await tester.pump(const Duration(seconds: 1));
      expect(_painted(tester), _sceneAt(shifted));

      await tester.tap(find.byKey(meadowTimeButtonKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Now').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(container.read(skyTimeProvider).offset, Duration.zero);
      expect(find.text(_clock(tester, sky.now)), findsOneWidget);
      expect(_painted(tester), _sceneAt(sky.now));
      expect(_painted(tester), before);
    },
  );
}
