import 'dart:async';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/core/capture_date.dart';
import 'package:field_notes/features/garden/model/garden_motion.dart';
import 'package:field_notes/features/garden/model/meadow_random.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/scene/meadow_pacer.dart';
import 'package:field_notes/features/garden/scene/meadow_stage.dart';
import 'package:field_notes/features/garden/scene/meadow_view.dart';
import 'package:field_notes/features/garden/sky/sky_scene.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

import 'garden_harness.dart';

const int meadowStageKey = 20250630;
const double meadowStageMargin = 20;
const int meadowBuildFrames = 6000;
const Size meadowSidebarCard = Size(1100, 502.9);

const double _latitude = 53.55;
const double _longitude = -113.4667;

final SkyScene meadowNoon = skySceneAt(
  DateTime.utc(2025, 6, 30, 19),
  _latitude,
  _longitude,
);

final SkyScene meadowMidnight = skySceneAt(
  DateTime.utc(2025, 7, 1, 6),
  _latitude,
  _longitude,
);

String _dateKey(int year, int month, int day) =>
    captureDateKey(DateTime(year, month, day));

MeadowYear meadowSampleYear() => MeadowYear.build(
  days: <Day>[
    for (int day = 13; day <= 23; day++)
      dayOf(_dateKey(2025, 1, day), mood: Mood.calm),
    dayOf(_dateKey(2025, 3, 5), mood: Mood.happy),
    dayOf(_dateKey(2025, 4, 20), mood: Mood.hopeful),
    dayOf(_dateKey(2025, 6, 30), mood: Mood.warm),
    dayOf(_dateKey(2025, 8, 8), mood: Mood.sad),
    dayOf(_dateKey(2025, 11, 11), mood: Mood.grateful),
  ],
  entryCounts: <String, int>{
    _dateKey(2025, 6, 30): 1,
    _dateKey(2025, 9, 15): 2,
  },
  year: 2025,
  today: DateTime(2026, 3, 1),
);

MeadowYear meadowLeapYear() => MeadowYear.build(
  days: <Day>[
    for (int i = 0; i < 366; i++)
      dayOf(
        captureDateKey(DateTime(2028, 1, 1 + i)),
        mood: moodOrder[(i ~/ 5) % moodOrder.length],
      ),
  ],
  entryCounts: <String, int>{
    for (int i = 0; i < 366; i++)
      captureDateKey(DateTime(2028, 1, 1 + i)): 1 + i % 4,
  },
  year: 2028,
  today: DateTime(2029, 3, 1),
);

typedef StageBatch = ({MeadowWork kind, int steps, SchedulerPhase phase});

class _GpuTime {
  int clock = 0;
  int pending = 0;
  int markers = 0;
}

class StageGpu extends MeadowPacer {
  StageGpu._(this._time, this._stepMicros)
    : super(
        nowMicros: () => _time.clock,
        marker: () {
          final int taken = _time.pending;
          _time.pending = 0;
          _time.markers++;
          return Future<void>.microtask(() => _time.clock += taken);
        },
      );

  factory StageGpu({required double stepMs}) =>
      StageGpu._(_GpuTime(), (stepMs * 1000).round());

  final _GpuTime _time;
  final int _stepMicros;
  final Map<MeadowBatch, ({MeadowWork kind, SchedulerPhase phase})> _begun =
      <MeadowBatch, ({MeadowWork kind, SchedulerPhase phase})>{};
  final List<StageBatch> sent = <StageBatch>[];
  MeadowStageState? busyStage;

  int get markers => _time.markers;

  @override
  int nowMicros() {
    final MeadowStageState? stage = busyStage;
    return super.nowMicros() +
        (stage == null
            ? 0
            : 3000 * (stage.debugBuildSteps + stage.debugRecolourPieces));
  }

  @override
  MeadowBatch begin(MeadowWork kind, {required Duration frame}) {
    final SchedulerPhase phase = SchedulerBinding.instance.schedulerPhase;
    final MeadowBatch batch = super.begin(kind, frame: frame);
    _begun[batch] = (kind: kind, phase: phase);
    return batch;
  }

  @override
  void end(
    MeadowBatch batch, {
    required int steps,
    void Function(Duration? cost)? answered,
  }) {
    final ({MeadowWork kind, SchedulerPhase phase}) begun = _begun.remove(
      batch,
    )!;
    if (begun.phase == SchedulerPhase.idle) {
      _time.pending += steps * _stepMicros;
    }
    sent.add((kind: begun.kind, steps: steps, phase: begun.phase));
    super.end(batch, steps: steps, answered: answered);
  }
}

class HeldGpu extends MeadowPacer {
  HeldGpu._(this.answers)
    : super(
        nowMicros: () => 0,
        marker: () {
          final Completer<void> answer = Completer<void>();
          answers.add(answer);
          return answer.future;
        },
      );

  factory HeldGpu() => HeldGpu._(<Completer<void>>[]);

  final List<Completer<void>> answers;
  final List<SchedulerPhase> phases = <SchedulerPhase>[];

  @override
  MeadowBatch begin(MeadowWork kind, {required Duration frame}) {
    phases.add(SchedulerBinding.instance.schedulerPhase);
    return super.begin(kind, frame: frame);
  }
}

T installPacer<T extends MeadowPacer>(T pacer) {
  final MeadowPacer original = meadowPacer;
  meadowPacer = pacer;
  addTearDown(() => meadowPacer = original);
  return pacer;
}

StageGpu useStageGpu({required double stepMs}) =>
    installPacer(StageGpu(stepMs: stepMs));

Future<MeadowStageState> pumpMeadowStage(
  WidgetTester tester, {
  MeadowYear? year,
  Size box = meadowSidebarCard,
  double ratio = 1,
  bool compact = false,
  MeadowSceneMode mode = MeadowSceneMode.page,
  GardenMotionProfile? motion = GardenMotionProfile.reduced,
  bool reduceMotion = false,
  bool tickers = true,
  int? growthPoint,
  Brightness brightness = Brightness.light,
  Key? stageKey,
  SkyScene? sky,
}) async {
  final MeadowYear shown = year ?? meadowSampleYear();
  tester.view.physicalSize =
      Size(
        box.width + 2 * meadowStageMargin,
        box.height + 2 * meadowStageMargin,
      ) *
      ratio;
  tester.view.devicePixelRatio = ratio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      key: ValueKey<Brightness>(brightness),
      debugShowCheckedModeBanner: false,
      theme: fieldNotesTheme(
        platform: compact ? TargetPlatform.android : TargetPlatform.macOS,
        brightness: brightness,
      ),
      home: Builder(
        builder: (BuildContext context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: reduceMotion),
          child: Scaffold(
            body: Center(
              child: SizedBox.fromSize(
                size: box,
                child: TickerMode(
                  enabled: tickers,
                  child: MeadowStage(
                    key: stageKey ?? UniqueKey(),
                    year: shown,
                    seed: meadowSeed(meadowStageKey, shown.year),
                    sky: sky ?? meadowNoon,
                    morning: false,
                    mode: mode,
                    compact: compact,
                    growthPoint: growthPoint,
                    motion: motion,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return tester.state<MeadowStageState>(find.byType(MeadowStage));
}

Future<void> growMeadow(WidgetTester tester, MeadowStageState state) async {
  for (int i = 0; i < meadowBuildFrames && !state.debugIsReady; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
    await tester.pump(const Duration(milliseconds: 1));
  }
  expect(state.debugIsReady, isTrue, reason: 'the meadow never finished');
}
