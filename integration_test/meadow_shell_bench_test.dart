import 'dart:ui';

import 'package:field_notes/app/app.dart';
import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/features/garden/render/meadow_stage_painter.dart';
import 'package:field_notes/features/garden/scene/meadow_scene_density.dart';
import 'package:field_notes/features/garden/scene/meadow_stage.dart';
import 'package:field_notes/features/garden/sky/sky_location.dart';
import 'package:field_notes/features/garden/sky/sky_location_provider.dart';
import 'package:field_notes/features/garden/sky/sky_time.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/shell_navigation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/bench_recorder.dart';
import 'support/integration_sandbox.dart';

const int _benchSeconds = int.fromEnvironment(
  'MEADOW_SHELL_BENCH_SECONDS',
  defaultValue: 10,
);
const Duration _measureFor = Duration(seconds: _benchSeconds);
const Duration _pollEvery = Duration(milliseconds: 16);
const Duration _shellLimit = Duration(seconds: 20);
const Duration _readyLimit = Duration(seconds: 20);
const Duration _sharpLimit = Duration(seconds: 20);
const Duration _settleFor = Duration(milliseconds: 1500);
const Duration _timingsSettle = Duration(milliseconds: 300);
const Duration _caseSlack = Duration(minutes: 4);
const double _densityTolerance = 0.999;

final DateTime _noon = DateTime.utc(2026, 10, 3, 19);
final DateTime _midnight = DateTime.utc(2026, 10, 3, 6);
final DateTime _today = DateTime(2026, 10, 3, 12);
final SkyLocation _edmonton = resolveSkyLocation(
  'America/Edmonton',
  const Duration(hours: -6),
);

const String _seedDays =
    'WITH RECURSIVE n(i) AS (SELECT 0 UNION ALL SELECT i + 1 FROM n '
    'WHERE i < 700) '
    'INSERT INTO days (id, date, mood_id, created_at, updated_at, deleted_at) '
    "SELECT 'bench-' || i, date('2025-01-01', '+' || i || ' days'), "
    'CASE ((i * 7 + i / 5) % 10) '
    "WHEN 0 THEN 'happy' WHEN 1 THEN 'love' WHEN 2 THEN 'warm' "
    "WHEN 3 THEN 'grateful' WHEN 4 THEN 'hopeful' WHEN 5 THEN 'calm' "
    "WHEN 6 THEN 'anxious' WHEN 7 THEN 'tired' WHEN 8 THEN 'sad' "
    "ELSE 'angry' END, 1790700000000, 1790700000000, NULL FROM n "
    "WHERE date('2025-01-01', '+' || i || ' days') <= '2026-10-03'";

const String _seedUnpaused =
    "INSERT INTO settings (key, value) VALUES ('meadow_pauses_when_inactive', "
    "'false')";

enum _Case {
  noon(label: 'noon', losesFocus: false),
  midnight(label: 'midnight', losesFocus: false),
  unfocused(label: 'unfocused', losesFocus: true);

  const _Case({required this.label, required this.losesFocus});

  final String label;
  final bool losesFocus;

  DateTime get instant => this == _Case.midnight ? _midnight : _noon;
}

MeadowStageState? _readyStage(WidgetTester tester) {
  final List<MeadowStageState> stages = tester
      .stateList<MeadowStageState>(
        find.byType(MeadowStage, skipOffstage: false),
      )
      .toList();
  for (final MeadowStageState stage in stages.reversed) {
    if (stage.debugIsReady) {
      return stage;
    }
  }
  return null;
}

List<MeadowStagePainter> _painters(WidgetTester tester) {
  return <MeadowStagePainter>[
    for (final CustomPaint paint in tester.widgetList<CustomPaint>(
      find.descendant(
        of: find.byType(MeadowStage, skipOffstage: false),
        matching: find.byType(CustomPaint, skipOffstage: false),
      ),
    ))
      if (paint.painter is MeadowStagePainter)
        paint.painter! as MeadowStagePainter,
  ];
}

double _screenDensity(WidgetTester tester) {
  final MeadowStage stage = tester.widget<MeadowStage>(
    find.byType(MeadowStage, skipOffstage: false).last,
  );
  return meadowSceneDensity(
    box: tester.getSize(find.byType(MeadowStage, skipOffstage: false).last),
    devicePixelRatio: tester.view.devicePixelRatio,
    cover: stage.covers,
    platform: defaultTargetPlatform,
  );
}

bool _isSharp(WidgetTester tester) {
  final List<MeadowStagePainter> painters = _painters(tester);
  if (painters.length != 1) {
    return false;
  }
  return painters.single.layers.density >=
      _screenDensity(tester) * _densityTolerance;
}

Future<bool> _until(
  WidgetTester tester,
  bool Function() condition,
  Duration limit,
) async {
  final Stopwatch waited = Stopwatch()..start();
  while (waited.elapsed < limit) {
    if (condition()) {
      return true;
    }
    await tester.binding.delayed(_pollEvery);
  }
  return condition();
}

int _longestUs(Iterable<FrameTiming> timings) => timings.fold<int>(
  0,
  (int longest, FrameTiming timing) => timing.totalSpan.inMicroseconds > longest
      ? timing.totalSpan.inMicroseconds
      : longest,
);

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

Widget _app(IntegrationSandbox sandbox, _Case bench) {
  return ProviderScope(
    overrides: <Override>[
      ...sandbox.overrides,
      todayClockProvider.overrideWithValue(() => _today),
      skyClockProvider.overrideWithValue(() => bench.instant),
      skyLocationProvider.overrideWith((Ref ref) async => _edmonton),
    ],
    child: const FieldNotesApp(),
  );
}

Future<void> _openMeadow(
  WidgetTester tester,
  IntegrationSandbox sandbox,
) async {
  await tester.pumpWidget(_app(sandbox, _Case.noon));
  final bool shown = await _until(
    tester,
    () => find.byType(AppShell).evaluate().isNotEmpty,
    _shellLimit,
  );
  if (!shown) {
    throw StateError('The app shell did not appear within $_shellLimit');
  }
  ProviderScope.containerOf(tester.element(find.byType(AppShell)))
      .read(shellNavigationProvider.notifier)
      .select(ShellDestination.garden);
  await tester.pump();
}

Future<void> _measureCase(WidgetTester tester, _Case bench) async {
  useLiveFrames(tester);
  adoptBenchSurface(tester);
  final double dpr = tester.view.devicePixelRatio;
  final Size logical = tester.view.physicalSize / dpr;
  BenchRecorder.instance.describeSurface(<String, Object?>{
    'logicalWidth': logical.width,
    'logicalHeight': logical.height,
    'devicePixelRatio': dpr,
  });

  final IntegrationSandbox sandbox = await IntegrationSandbox.create(
    'meadow-shell-${bench.label}',
  );
  addTearDown(sandbox.dispose);
  await tester.runAsync(() => sandbox.database.customStatement(_seedDays));
  if (bench.losesFocus) {
    await tester.runAsync(
      () => sandbox.database.customStatement(_seedUnpaused),
    );
  }

  final List<FrameTiming> sharpening = <FrameTiming>[];
  final List<FrameTiming> settling = <FrameTiming>[];
  final List<FrameTiming> steady = <FrameTiming>[];
  List<FrameTiming> sink = settling;
  void collect(List<FrameTiming> batch) => sink.addAll(batch);
  SchedulerBinding.instance.addTimingsCallback(collect);

  await tester.pumpWidget(_app(sandbox, bench));
  final bool shown = await _until(
    tester,
    () => find.byType(AppShell).evaluate().isNotEmpty,
    _shellLimit,
  );
  if (!shown) {
    throw StateError('The app shell did not appear within $_shellLimit');
  }
  ProviderScope.containerOf(tester.element(find.byType(AppShell)))
      .read(shellNavigationProvider.notifier)
      .select(ShellDestination.garden);
  await tester.pump();

  final bool ready = await _until(
    tester,
    () => _readyStage(tester) != null,
    _readyLimit,
  );
  if (!ready) {
    throw StateError('The meadow scene was not ready within $_readyLimit');
  }
  sink = sharpening;
  final bool sharp = await _until(tester, () => _isSharp(tester), _sharpLimit);
  await tester.binding.delayed(_timingsSettle);

  sink = settling;
  if (bench.losesFocus) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  }
  await tester.binding.delayed(_settleFor);

  final MeadowStageState stage = _readyStage(tester)!;
  final int stageBytes = stage.debugImageBytes;
  sink = steady;
  await tester.binding.delayed(_measureFor);
  await tester.binding.delayed(_timingsSettle);
  SchedulerBinding.instance.removeTimingsCallback(collect);
  if (bench.losesFocus) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  }

  final Map<String, Object?> extra = <String, Object?>{
    'case': bench.label,
    'seconds': _measureFor.inSeconds,
    'frames': steady.length,
    'sharpeningFrames': sharpening.length,
    'sceneSharp': sharp,
    'sceneImageBytes': stageBytes,
    'debugImageBytes': stage.debugImageBytes,
    'screenDensity': _screenDensity(tester),
    'logicalWidth': logical.width,
    'logicalHeight': logical.height,
    'devicePixelRatio': dpr,
    'unfocused': bench.losesFocus,
    'budget': 'none; judged in the owner device check against spec 10.15',
  };
  final String prefix = 'meadow.shell.${bench.label}';
  await _record(
    id: '$prefix.raster',
    what:
        'raster thread time of each engine frame over ${_measureFor.inSeconds} '
        's: ${bench.label}',
    samplesUs: <int>[
      for (final FrameTiming timing in steady)
        timing.rasterDuration.inMicroseconds,
    ],
    extra: extra,
  );
  await _record(
    id: '$prefix.build',
    what:
        'UI thread build time of each engine frame over '
        '${_measureFor.inSeconds} s: ${bench.label}',
    samplesUs: <int>[
      for (final FrameTiming timing in steady)
        timing.buildDuration.inMicroseconds,
    ],
    extra: extra,
  );
  await _record(
    id: '$prefix.frames',
    what:
        'number of engine frames over ${_measureFor.inSeconds} s: '
        '${bench.label}',
    samplesUs: <int>[steady.length],
    extra: extra,
  );
  await _record(
    id: '$prefix.longestFrame',
    what: 'longest frame over ${_measureFor.inSeconds} s: ${bench.label}',
    samplesUs: <int>[_longestUs(steady)],
    extra: extra,
  );
  await _record(
    id: '$prefix.sharpeningLongestFrame',
    what:
        'longest frame from the first ready scene until the crossfade ends: '
        '${bench.label}',
    samplesUs: <int>[_longestUs(sharpening)],
    extra: extra,
  );

  await tester.pumpWidget(const SizedBox());
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('meadow shell warm-up before measuring', (
    WidgetTester tester,
  ) async {
    useLiveFrames(tester);
    adoptBenchSurface(tester);
    final IntegrationSandbox sandbox = await IntegrationSandbox.create(
      'meadow-shell-warm',
    );
    addTearDown(sandbox.dispose);
    await tester.runAsync(() => sandbox.database.customStatement(_seedDays));
    await _openMeadow(tester, sandbox);
    await _until(tester, () => _readyStage(tester) != null, _readyLimit);
    await _until(tester, () => _isSharp(tester), _sharpLimit);
    await tester.pumpWidget(const SizedBox());
  }, semanticsEnabled: false);

  for (final _Case bench in _Case.values) {
    testWidgets(
      'meadow in the app shell at ${bench.label}',
      (WidgetTester tester) => _measureCase(tester, bench),
      semanticsEnabled: false,
      timeout: Timeout(_measureFor + _caseSlack),
    );
  }
}
