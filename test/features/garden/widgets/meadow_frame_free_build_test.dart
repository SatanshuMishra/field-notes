import 'dart:async';

import 'package:field_notes/features/garden/render/meadow_stage_painter.dart';
import 'package:field_notes/features/garden/scene/meadow_stage.dart';
import 'package:field_notes/features/garden/scene/meadow_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/image_count.dart';
import '../support/meadow_stage_harness.dart';

const int _snapshotsPerGap = 4;

const Set<SchedulerPhase> _framePhases = <SchedulerPhase>{
  SchedulerPhase.transientCallbacks,
  SchedulerPhase.postFrameCallbacks,
};

final Finder _stagePaints = find.byWidgetPredicate(
  (Widget widget) =>
      widget is CustomPaint && widget.painter is MeadowStagePainter,
);

MeadowStagePainter _stagePainter(WidgetTester tester) =>
    tester.widget<CustomPaint>(_stagePaints).painter! as MeadowStagePainter;

ImageCount _countImages() {
  final ImageCount count = ImageCount()..start();
  addTearDown(count.stop);
  return count;
}

Future<void> _wait(WidgetTester tester) => tester.runAsync(
  () => Future<void>.delayed(const Duration(milliseconds: 2)),
);

void _answerAll(HeldGpu gpu) {
  for (final Completer<void> answer in gpu.answers) {
    if (!answer.isCompleted) {
      answer.complete();
    }
  }
}

Future<void> _untilBehind(WidgetTester tester, HeldGpu gpu) async {
  for (
    int i = 0;
    i < meadowBuildFrames && (gpu.phases.length < 2 || !gpu.isBehind);
    i++
  ) {
    await _wait(tester);
    await tester.pump(Duration.zero);
  }
  expect(gpu.phases, hasLength(2), reason: 'two batches begun');
  expect(gpu.answers, hasLength(1), reason: 'one marker waits');
  expect(gpu.isBehind, isTrue, reason: 'one batch carried behind it');
}

Future<List<StageBatch>> _buildWithoutFrames(
  WidgetTester tester, {
  required double stepMs,
  required bool busy,
}) async {
  final StageGpu gpu = useStageGpu(stepMs: stepMs);
  final MeadowStageState state = await pumpMeadowStage(
    tester,
    year: meadowLeapYear(),
  );
  if (busy) {
    gpu.busyStage = state;
  }
  for (int i = 0; i < meadowBuildFrames && !state.debugIsReady; i++) {
    await _wait(tester);
    await tester.pump(const Duration(milliseconds: 1));
  }
  expect(state.debugIsReady, isTrue, reason: 'the meadow never finished');
  final List<StageBatch> sent = List<StageBatch>.of(gpu.sent);
  await tester.pumpWidget(const SizedBox());
  return sent;
}

Future<void> _coverOrHide(WidgetTester tester, {required bool cover}) async {
  final HeldGpu gpu = installPacer(HeldGpu());
  final MeadowStageState state = await pumpMeadowStage(tester);
  await _untilBehind(tester, gpu);
  expect(
    gpu.phases,
    everyElement(SchedulerPhase.idle),
    reason: 'the first two batches ran without frames',
  );
  final int before = gpu.phases.length;

  final NavigatorState navigator = tester.state<NavigatorState>(
    find.byType(Navigator),
  );
  if (cover) {
    unawaited(
      navigator.push(
        PageRouteBuilder<void>(
          pageBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondary,
          ) => const ColoredBox(color: Color(0xFFFFFFFF)),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      ),
    );
  } else {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  }
  for (int i = 0; i < 20; i++) {
    _answerAll(gpu);
    await _wait(tester);
    await tester.pump(const Duration(milliseconds: 1));
  }
  final List<SchedulerPhase> away = gpu.phases.sublist(before);
  if (cover) {
    expect(away, isNotEmpty, reason: 'the covered meadow kept building');
    for (final SchedulerPhase phase in away) {
      expect(_framePhases, contains(phase), reason: '$away');
    }
    navigator.pop();
  } else {
    expect(away, isEmpty, reason: 'the hidden meadow sent $away');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  }

  final int back = gpu.phases.length;
  for (int i = 0; i < meadowBuildFrames && !state.debugIsReady; i++) {
    _answerAll(gpu);
    await _wait(tester);
    await tester.pump(const Duration(milliseconds: 1));
  }
  expect(state.debugIsReady, isTrue, reason: 'the meadow never finished');
  expect(gpu.phases.length, greaterThan(back));
  await tester.pumpWidget(const SizedBox());
}

void main() {
  testWidgets(
    'a meadow with nothing shown builds its first scene without frames',
    (WidgetTester tester) async {
      final StageGpu gpu = useStageGpu(stepMs: 0.1);
      int frames = 0;
      tester.binding.addPersistentFrameCallback((Duration timeStamp) {
        frames++;
      });
      final MeadowStageState state = await pumpMeadowStage(
        tester,
        sky: meadowNoon,
        tickers: false,
      );
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(gpu.sent, isEmpty);
      final int drawn = frames;
      for (int i = 0; i < meadowBuildFrames && !state.debugIsReady; i++) {
        await _wait(tester);
        await tester.pump(const Duration(milliseconds: 1));
        if (!state.debugIsReady) {
          expect(frames, drawn, reason: 'pump $i drew a frame');
        }
      }
      expect(state.debugIsReady, isTrue, reason: 'the meadow never finished');
      expect(gpu.sent, isNotEmpty);
      expect(
        gpu.sent.map((StageBatch batch) => batch.phase),
        everyElement(SchedulerPhase.idle),
      );
    },
  );

  testWidgets(
    'a frame-free batch stops at half a frame of processor time or eight '
    'frames of GPU time',
    (WidgetTester tester) async {
      final List<StageBatch> still = await _buildWithoutFrames(
        tester,
        stepMs: 12,
        busy: false,
      );
      final List<int> stillSteps = <int>[
        for (final StageBatch batch in still) batch.steps,
      ];
      expect(stillSteps, everyElement(lessThanOrEqualTo(11)));
      expect(stillSteps, contains(11), reason: '$stillSteps');

      final List<StageBatch> busy = await _buildWithoutFrames(
        tester,
        stepMs: 0.1,
        busy: true,
      );
      final List<int> busySteps = <int>[
        for (final StageBatch batch in busy) batch.steps,
      ];
      expect(busySteps, everyElement(lessThanOrEqualTo(3)));
      expect(busySteps, contains(3), reason: '$busySteps');
    },
  );

  testWidgets(
    'a meadow builds on frames while a frame is scheduled or a scene is shown',
    (WidgetTester tester) async {
      final StageGpu framed = useStageGpu(stepMs: 0.1);
      MeadowStageState state = await pumpMeadowStage(
        tester,
        sky: meadowNoon,
        tickers: false,
      );
      for (int i = 0; i < meadowBuildFrames && !state.debugIsReady; i++) {
        await _wait(tester);
        tester.binding.scheduleFrame();
        await tester.pump(const Duration(milliseconds: 1));
      }
      expect(state.debugIsReady, isTrue, reason: 'the meadow never finished');
      expect(framed.sent, isNotEmpty);
      for (final StageBatch batch in framed.sent) {
        expect(_framePhases, contains(batch.phase), reason: 'first build');
      }
      await tester.pumpWidget(const SizedBox());

      final StageGpu sharpen = useStageGpu(stepMs: 0.1);
      const double ratio = 2;
      state = await pumpMeadowStage(
        tester,
        year: meadowLeapYear(),
        ratio: ratio,
        tickers: false,
      );
      await growMeadow(tester, state);
      final double screen =
          MeadowViewport.resolve(
            box: meadowSidebarCard,
            cover: false,
            focusX: 0,
          ).scale *
          ratio;
      expect(_stagePainter(tester).layers.density, lessThan(screen));
      bool sharp() =>
          (_stagePainter(tester).layers.density - screen).abs() < 1e-9;
      final int shown = sharpen.sent.length;
      final ImageCount count = _countImages();
      final List<int> perPump = <int>[];
      for (int i = 0; i < meadowBuildFrames && !sharp(); i++) {
        await _wait(tester);
        final int before = count.created;
        await tester.pump(const Duration(milliseconds: 1));
        perPump.add(count.created - before);
      }
      expect(sharp(), isTrue, reason: 'the meadow never sharpened');
      final List<StageBatch> sharpening = sharpen.sent.sublist(shown);
      expect(sharpening, isNotEmpty);
      for (final StageBatch batch in sharpening) {
        expect(_framePhases, contains(batch.phase), reason: 'sharpen build');
      }
      expect(
        perPump,
        everyElement(lessThanOrEqualTo(_snapshotsPerGap)),
        reason: '$perPump',
      );
    },
  );

  testWidgets(
    'a covered or hidden meadow sends no build batch without frames',
    (WidgetTester tester) async {
      await _coverOrHide(tester, cover: true);
      await _coverOrHide(tester, cover: false);
    },
  );

  testWidgets('disposing a meadow cancels its pending build timer', (
    WidgetTester tester,
  ) async {
    final HeldGpu gpu = installPacer(HeldGpu());
    await pumpMeadowStage(tester);
    await _untilBehind(tester, gpu);
    expect(gpu.phases, <SchedulerPhase>[
      SchedulerPhase.idle,
      SchedulerPhase.idle,
    ]);

    await tester.pumpWidget(const SizedBox());
    for (int i = 0; i < 4; i++) {
      await tester.pump(Duration.zero);
    }
    expect(gpu.phases, hasLength(2), reason: 'no batch after the stage left');
  });

  testWidgets(
    'a frame-free build stops each batch at its bound, waits 1 ms while the '
    'pacer is behind and still builds its first scene',
    (WidgetTester tester) async {
      final List<int> stillSteps = <int>[
        for (final StageBatch batch in await _buildWithoutFrames(
          tester,
          stepMs: 12,
          busy: false,
        ))
          batch.steps,
      ];
      expect(stillSteps, everyElement(lessThanOrEqualTo(11)));
      expect(stillSteps, contains(11), reason: '$stillSteps');

      final List<int> busySteps = <int>[
        for (final StageBatch batch in await _buildWithoutFrames(
          tester,
          stepMs: 0.1,
          busy: true,
        ))
          batch.steps,
      ];
      expect(busySteps, everyElement(lessThanOrEqualTo(3)));
      expect(busySteps, contains(3), reason: '$busySteps');

      final HeldGpu held = installPacer(HeldGpu());
      final MeadowStageState state = await pumpMeadowStage(
        tester,
        tickers: false,
      );
      for (int i = 0; i < meadowBuildFrames && held.phases.length < 2; i++) {
        await _wait(tester);
        await tester.pump(Duration.zero);
      }
      expect(held.phases, <SchedulerPhase>[
        SchedulerPhase.idle,
        SchedulerPhase.idle,
      ]);
      expect(held.answers, hasLength(1), reason: 'the marker is called once');
      expect(held.isBehind, isTrue, reason: 'the second batch is carried');
      for (int i = 0; i < 8; i++) {
        await _wait(tester);
        await tester.pump(Duration.zero);
      }
      expect(held.phases, hasLength(2), reason: 'no third batch while behind');

      held.answers[0].complete();
      await _wait(tester);
      await tester.pump(Duration.zero);
      expect(held.isBehind, isFalse, reason: 'the first marker answered');
      expect(held.phases, hasLength(2), reason: 'the step waits its 1 ms');

      await _wait(tester);
      await tester.pump(const Duration(milliseconds: 1));
      expect(held.phases, <SchedulerPhase>[
        SchedulerPhase.idle,
        SchedulerPhase.idle,
        SchedulerPhase.idle,
        SchedulerPhase.idle,
      ], reason: 'the third batch after 1 ms and a fourth carried behind it');
      expect(held.answers, hasLength(2), reason: 'the third end marks');
      expect(held.isBehind, isTrue, reason: 'the fourth batch is carried');

      for (int i = 0; i < meadowBuildFrames && !state.debugIsReady; i++) {
        _answerAll(held);
        await _wait(tester);
        await tester.pump(const Duration(milliseconds: 1));
      }
      expect(state.debugIsReady, isTrue, reason: 'the meadow never finished');
    },
  );
}
