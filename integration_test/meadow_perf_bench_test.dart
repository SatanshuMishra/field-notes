import 'dart:ui';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/garden/garden_screen.dart';
import 'package:field_notes/features/garden/model/meadow_key_provider.dart';
import 'package:field_notes/features/garden/model/meadow_random.dart';
import 'package:field_notes/features/garden/model/meadow_view_state.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/scene/meadow_stage.dart';
import 'package:field_notes/features/garden/sky/sky_location.dart';
import 'package:field_notes/features/garden/sky/sky_location_provider.dart';
import 'package:field_notes/features/garden/sky/sky_time.dart';
import 'package:field_notes/features/garden/widgets/meadow_full_screen.dart';
import 'package:field_notes/features/streak/journaled_dates_provider.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/bench_recorder.dart';

const Size _desktopSurface = Size(1140, 766);
const Duration _animateFor = Duration(seconds: 10);
const Duration _pollEvery = Duration(milliseconds: 16);
const Duration _readyLimit = Duration(seconds: 10);
const Duration _timingsSettle = Duration(milliseconds: 300);
const int _meadowKey = 24601;
const int _currentYear = 2028;
const int _studyYear = 2027;
const int _moodCycle = 7;
const int _entryCycle = 4;

final DateTime _noon = DateTime.utc(_currentYear, 12, 31, 19);
final DateTime _midnight = DateTime.utc(_currentYear, 12, 31, 7);
final SkyLocation _edmonton = resolveSkyLocation(
  'America/Edmonton',
  const Duration(hours: -7),
);

enum _View { page, study, fullScreen }

enum _Layout { sidebar, bottomBar }

enum _Hour { noon, midnight }

String _dateOf(int year, int index) => DateTime.utc(
  year,
  1,
  1,
).add(Duration(days: index)).toIso8601String().substring(0, 10);

int _daysIn(int year) =>
    DateTime.utc(year + 1).difference(DateTime.utc(year)).inDays;

final List<Day> _days = <Day>[
  for (final int year in <int>[_studyYear, _currentYear])
    for (int index = 0; index < _daysIn(year); index++)
      Day(
        id: 'bench-${_dateOf(year, index)}',
        date: _dateOf(year, index),
        mood: moodOrder[(index * _moodCycle + index ~/ 5) % moodOrder.length],
        createdAt: 0,
        updatedAt: 0,
      ),
];

final Map<String, int> _entryCounts = <String, int>{
  for (int index = 0; index < _days.length; index++)
    _days[index].date: 1 + index % _entryCycle,
};

void _adoptSurface(WidgetTester tester, _Layout layout) {
  if (benchOnDevice) {
    return;
  }
  if (layout == _Layout.bottomBar) {
    adoptBenchSurface(tester);
    return;
  }
  tester.view.physicalSize = _desktopSurface * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
}

ProviderContainer _containerFor(_Hour hour, _View view) {
  final DateTime instant = hour == _Hour.noon ? _noon : _midnight;
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      allDaysProvider.overrideWith((Ref ref) => Stream<List<Day>>.value(_days)),
      journalEntryCountsProvider.overrideWith(
        (Ref ref) => Stream<Map<String, int>>.value(_entryCounts),
      ),
      meadowKeyProvider.overrideWith(
        (Ref ref) => Future<int>.value(_meadowKey),
      ),
      skyClockProvider.overrideWithValue(() => instant),
      skyLocationProvider.overrideWith((Ref ref) async => _edmonton),
      skyDebugControlsProvider.overrideWithValue(false),
    ],
  );
  if (view == _View.study) {
    container
        .read(meadowViewStateProvider.notifier)
        .openYear(_studyYear, currentYear: _currentYear);
  }
  return container;
}

Widget _app(ProviderContainer container, _Layout layout) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: fieldNotesTheme(
        platform: layout == _Layout.sidebar
            ? TargetPlatform.macOS
            : TargetPlatform.android,
      ),
      home: const Scaffold(body: GardenScreen()),
    ),
  );
}

MeadowStageState? _newestStage(WidgetTester tester, int known) {
  final List<MeadowStageState> stages = tester
      .stateList<MeadowStageState>(find.byType(MeadowStage))
      .toList();
  return stages.length > known ? stages.last : null;
}

class _Landing {
  const _Landing({required this.stage, required this.readyAfter});

  final MeadowStageState stage;
  final Duration readyAfter;
}

Future<_Landing> _awaitScene(
  WidgetTester tester,
  Stopwatch mounted, {
  required int known,
}) async {
  while (mounted.elapsed < _readyLimit) {
    final MeadowStageState? stage = _newestStage(tester, known);
    if (stage != null && stage.debugIsReady) {
      mounted.stop();
      return _Landing(stage: stage, readyAfter: mounted.elapsed);
    }
    await tester.binding.delayed(_pollEvery);
  }
  throw StateError('The meadow scene was not ready within $_readyLimit');
}

Future<void> _record({
  required String id,
  required String what,
  required List<int> samplesUs,
  required Map<String, Object?> extra,
}) => BenchRecorder.instance.record(
  BenchMeasurement(
    id: id,
    what: what,
    samplesUs: List<int>.unmodifiable(samplesUs),
    extra: extra,
  ),
);

void _openFullScreen(
  WidgetTester tester,
  ProviderContainer container, {
  required _Layout layout,
  required _Hour hour,
}) {
  final MeadowYear year = MeadowYear.build(
    days: _days,
    entryCounts: _entryCounts,
    year: _currentYear,
    today: (hour == _Hour.noon ? _noon : _midnight).toLocal(),
  );
  final MeadowFullScreenRequest request = MeadowFullScreenRequest(
    year: _currentYear,
    hourMinutes: null,
    growthPoint: year.limit,
  );
  container.read(meadowViewStateProvider.notifier).openFullScreen(request);
  openMeadowFullScreen(
    tester.element(find.byType(GardenScreen)),
    request: request,
    year: year,
    seed: meadowSeed(_meadowKey, _currentYear),
    compact: layout == _Layout.bottomBar,
    isCurrentYear: true,
  );
}

Future<void> _measureCase(
  WidgetTester tester, {
  required _View view,
  required _Layout layout,
  required _Hour hour,
}) async {
  useLiveFrames(tester);
  _adoptSurface(tester, layout);
  final double dpr = tester.view.devicePixelRatio;
  final Size logical = tester.view.physicalSize / dpr;
  BenchRecorder.instance.describeSurface(<String, Object?>{
    'logicalWidth': logical.width,
    'logicalHeight': logical.height,
    'devicePixelRatio': dpr,
  });

  final ProviderContainer container = _containerFor(hour, view);
  addTearDown(container.dispose);

  final List<FrameTiming> arrival = <FrameTiming>[];
  final List<FrameTiming> steady = <FrameTiming>[];
  List<FrameTiming> sink = arrival;
  void collect(List<FrameTiming> batch) => sink.addAll(batch);
  SchedulerBinding.instance.addTimingsCallback(collect);

  final Stopwatch mounted = Stopwatch()..start();
  await tester.pumpWidget(_app(container, layout));
  final int underneath;
  if (view == _View.fullScreen) {
    await _awaitScene(tester, Stopwatch()..start(), known: 0);
    underneath = 1;
    arrival.clear();
    mounted
      ..reset()
      ..start();
    _openFullScreen(tester, container, layout: layout, hour: hour);
    await tester.pump();
  } else {
    underneath = 0;
  }
  final _Landing landing = await _awaitScene(
    tester,
    mounted,
    known: underneath,
  );
  await tester.binding.delayed(_timingsSettle);
  final int stageBytes = landing.stage.debugImageBytes;

  sink = steady;
  await tester.binding.delayed(_animateFor);
  await tester.binding.delayed(_timingsSettle);
  SchedulerBinding.instance.removeTimingsCallback(collect);

  final List<FrameTiming> everything = <FrameTiming>[...arrival, ...steady];
  final int longestUs = everything.fold<int>(
    0,
    (int longest, FrameTiming timing) =>
        timing.totalSpan.inMicroseconds > longest
        ? timing.totalSpan.inMicroseconds
        : longest,
  );
  final int longestSteadyUs = steady.fold<int>(
    0,
    (int longest, FrameTiming timing) =>
        timing.totalSpan.inMicroseconds > longest
        ? timing.totalSpan.inMicroseconds
        : longest,
  );
  final String name = '${view.name}.${layout.name}.${hour.name}';
  final Map<String, Object?> extra = <String, Object?>{
    'view': view.name,
    'layout': layout.name,
    'hour': hour.name,
    'blooms': _daysIn(_currentYear),
    'meadowKey': _meadowKey,
    'seconds': _animateFor.inSeconds,
    'steadyFrames': steady.length,
    'arrivalFrames': arrival.length,
    'sceneImageBytes': stageBytes,
    'sceneReadyMs': landing.readyAfter.inMicroseconds / 1000,
    'longestFrameMs': longestUs / 1000,
    'longestSteadyFrameMs': longestSteadyUs / 1000,
    'motion': 'full',
    'budget': 'none; judged in the live pass against spec 16.22',
  };
  await _record(
    id: 'meadow.$name.build',
    what:
        'UI thread build time of each engine frame over '
        '${_animateFor.inSeconds} s: $name',
    samplesUs: <int>[
      for (final FrameTiming timing in steady)
        timing.buildDuration.inMicroseconds,
    ],
    extra: extra,
  );
  await _record(
    id: 'meadow.$name.raster',
    what:
        'raster thread time of each engine frame over '
        '${_animateFor.inSeconds} s: $name',
    samplesUs: <int>[
      for (final FrameTiming timing in steady)
        timing.rasterDuration.inMicroseconds,
    ],
    extra: extra,
  );
  await _record(
    id: 'meadow.$name.sceneReady',
    what: 'time from mount to the scene being ready: $name',
    samplesUs: <int>[landing.readyAfter.inMicroseconds],
    extra: extra,
  );
  await _record(
    id: 'meadow.$name.longestFrame',
    what: 'longest frame from mount through the animation: $name',
    samplesUs: <int>[longestUs],
    extra: extra,
  );

  await tester.pumpWidget(const SizedBox());
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  for (final _View view in _View.values) {
    for (final _Layout layout in _Layout.values) {
      for (final _Hour hour in _Hour.values) {
        testWidgets(
          'meadow ${view.name} on the ${layout.name} layout at ${hour.name}',
          (WidgetTester tester) =>
              _measureCase(tester, view: view, layout: layout, hour: hour),
        );
      }
    }
  }
}
