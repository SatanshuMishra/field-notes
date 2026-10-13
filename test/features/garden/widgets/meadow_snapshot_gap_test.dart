import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:field_notes/features/garden/render/meadow_rays.dart';
import 'package:field_notes/features/garden/render/meadow_stage_painter.dart';
import 'package:field_notes/features/garden/scene/meadow_pacer.dart';
import 'package:field_notes/features/garden/scene/meadow_stage.dart';
import 'package:field_notes/features/garden/scene/meadow_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/image_count.dart';
import '../support/meadow_stage_harness.dart';

const int _snapshotsPerGap = 4;

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

Future<MeadowStageState> _openAtNoon(WidgetTester tester, Key key) async {
  final MeadowStageState state = await pumpMeadowStage(
    tester,
    stageKey: key,
    sky: meadowNoon,
    tickers: false,
  );
  await growMeadow(tester, state);
  for (int i = 0; i < 64 && state.debugIsRecolouring; i++) {
    await tester.pump();
  }
  expect(state.debugIsRecolouring, isFalse);
  return state;
}

Future<List<int>> _growOnFrames(
  WidgetTester tester,
  MeadowStageState state,
  ImageCount count,
) async {
  final List<int> perPump = <int>[];
  for (int i = 0; i < meadowBuildFrames && !state.debugIsReady; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
    final int before = count.created;
    tester.binding.scheduleFrame();
    await tester.pump(const Duration(milliseconds: 1));
    perPump.add(count.created - before);
  }
  expect(state.debugIsReady, isTrue, reason: 'the meadow never finished');
  return perPump;
}

Future<Uint8List> _bytesOf(WidgetTester tester, ui.Image image) async {
  final ByteData? data = await tester.runAsync<ByteData?>(
    () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
  );
  return data!.buffer.asUint8List();
}

void main() {
  testWidgets(
    'a sky change on an open meadow renders at most four images between two '
    'frames',
    (WidgetTester tester) async {
      useStageGpu(stepMs: 0.1);
      const Key key = ValueKey<String>('snapshot gap stage');
      MeadowStageState state = await pumpMeadowStage(
        tester,
        stageKey: key,
        sky: meadowNoon,
        tickers: false,
      );
      for (int i = 0; i < meadowBuildFrames && !state.debugIsReady; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 2)),
        );
        await tester.pump(Duration.zero);
      }
      expect(state.debugIsReady, isTrue, reason: 'the meadow never finished');
      for (int i = 0; i < 64 && state.debugIsRecolouring; i++) {
        await tester.pump();
      }
      expect(state.debugIsRecolouring, isFalse);

      final ImageCount count = ImageCount()..start();
      addTearDown(count.stop);
      final List<int> perFrame = <int>[];
      state = await pumpMeadowStage(
        tester,
        stageKey: key,
        sky: meadowMidnight,
        tickers: false,
      );
      perFrame.add(count.created);
      count.created = 0;
      for (int i = 0; i < 64 && state.debugIsRecolouring; i++) {
        await tester.pump();
        perFrame.add(count.created);
        count.created = 0;
      }
      expect(state.debugIsRecolouring, isFalse);
      expect(
        perFrame.fold<int>(0, (int total, int images) => total + images),
        greaterThan(_snapshotsPerGap),
        reason: 'the recolour redrew several pieces',
      );
      for (int i = 0; i < perFrame.length; i++) {
        expect(
          perFrame[i],
          lessThanOrEqualTo(_snapshotsPerGap),
          reason: 'frame $i of $perFrame',
        );
      }
    },
  );

  testWidgets(
    'a sky that changes every frame keeps the rays and the pieces within four '
    'images a gap',
    (WidgetTester tester) async {
      useStageGpu(stepMs: 0.1);
      const Key key = ValueKey<String>('changing sky stage');
      MeadowStageState state = await _openAtNoon(tester, key);

      final ImageCount count = _countImages();
      final List<int> perPump = <int>[];
      for (int i = 0; i < 24; i++) {
        final int before = count.created;
        state = await pumpMeadowStage(
          tester,
          stageKey: key,
          sky: i.isEven ? meadowMidnight : meadowNoon,
          tickers: false,
        );
        perPump.add(count.created - before);
      }
      int before = count.created;
      state = await pumpMeadowStage(
        tester,
        stageKey: key,
        sky: meadowMidnight,
        tickers: false,
      );
      perPump.add(count.created - before);
      for (int i = 0; i < 64 && state.debugIsRecolouring; i++) {
        before = count.created;
        await tester.pump();
        perPump.add(count.created - before);
      }
      expect(state.debugIsRecolouring, isFalse);
      expect(
        perPump,
        everyElement(lessThanOrEqualTo(_snapshotsPerGap)),
        reason: '$perPump',
      );

      final MeadowStagePainter painter = _stagePainter(tester);
      final MeadowRays fresh = MeadowRays(painter.palette)..buildAll();
      addTearDown(fresh.dispose);
      expect(
        await _bytesOf(tester, painter.rays.image),
        await _bytesOf(tester, fresh.image),
      );
    },
  );

  testWidgets(
    'a sun-colour change redraws the rays in the next frame with room and '
    'repaints',
    (WidgetTester tester) async {
      useStageGpu(stepMs: 0.1);
      const Key key = ValueKey<String>('sun colour stage');
      MeadowStageState state = await _openAtNoon(tester, key);
      final MeadowStagePainter noon = _stagePainter(tester);
      final ui.Image noonRays = noon.rays.image;

      final ImageCount count = _countImages();
      state = await pumpMeadowStage(
        tester,
        stageKey: key,
        sky: meadowMidnight,
        tickers: false,
      );
      final MeadowStagePainter applied = _stagePainter(tester);
      expect(applied.rays.image, same(noonRays));
      expect(applied.raysRevision, noon.raysRevision);
      expect(state.debugIsRecolouring, isTrue);

      final int before = count.created;
      await tester.pump();
      final MeadowStagePainter redrawn = _stagePainter(tester);
      expect(count.created - before, lessThanOrEqualTo(_snapshotsPerGap));
      expect(redrawn.raysRevision, applied.raysRevision + 1);
      expect(redrawn.rays.image, isNot(same(noonRays)));
      expect(redrawn.shouldRepaint(applied), isTrue);
    },
  );

  testWidgets(
    'the last build steps render the creature art and the rays one image at '
    'a time',
    (WidgetTester tester) async {
      final StageGpu gpu = useStageGpu(stepMs: 0.1);
      final ImageCount count = _countImages();
      final MeadowStageState state = await pumpMeadowStage(
        tester,
        sky: meadowNoon,
        tickers: false,
      );
      final List<int> perPump = await _growOnFrames(tester, state, count);
      expect(
        perPump,
        everyElement(lessThanOrEqualTo(_snapshotsPerGap)),
        reason: '$perPump',
      );
      expect(
        gpu.sent
            .where((StageBatch batch) => batch.kind == MeadowWork.finish)
            .fold<int>(0, (int total, StageBatch batch) => total + batch.steps),
        4,
      );
    },
  );

  testWidgets(
    'a build on frames renders four images a frame even when the GPU estimate '
    'allows one step',
    (WidgetTester tester) async {
      useStageGpu(stepMs: 12);
      final ImageCount count = _countImages();
      final MeadowStageState state = await pumpMeadowStage(
        tester,
        sky: meadowNoon,
        tickers: false,
      );
      final List<int> perPump = await _growOnFrames(tester, state, count);
      expect(
        perPump,
        everyElement(lessThanOrEqualTo(_snapshotsPerGap)),
        reason: '$perPump',
      );
      expect(perPump, contains(_snapshotsPerGap), reason: '$perPump');
    },
  );

  testWidgets(
    'a build batch on frames stops at half the frame interval of processor '
    'time',
    (WidgetTester tester) async {
      final StageGpu gpu = useStageGpu(stepMs: 12);
      final MeadowStageState state = await pumpMeadowStage(
        tester,
        year: meadowLeapYear(),
      );
      gpu.busyStage = state;
      int threes = 0;
      for (int i = 0; i < meadowBuildFrames && !state.debugIsReady; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 2)),
        );
        final int steps = state.debugBuildSteps;
        tester.binding.scheduleFrame();
        await tester.pump(const Duration(milliseconds: 1));
        final int stepped = state.debugBuildSteps - steps;
        expect(stepped, lessThanOrEqualTo(3), reason: 'pump $i');
        if (stepped == 3) {
          threes++;
        }
      }
      expect(state.debugIsReady, isTrue);
      expect(threes, greaterThan(0));
    },
  );

  testWidgets(
    'a sharpen build under a shown scene renders at most four images a frame',
    (WidgetTester tester) async {
      useStageGpu(stepMs: 0.1);
      const double ratio = 2;
      final MeadowStageState state = await pumpMeadowStage(
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
      final ImageCount count = _countImages();
      final List<int> perPump = <int>[];
      for (int i = 0; i < meadowBuildFrames && !sharp(); i++) {
        final int before = count.created;
        await tester.pump(const Duration(milliseconds: 16));
        perPump.add(count.created - before);
      }
      expect(sharp(), isTrue, reason: 'the meadow never sharpened');
      expect(
        perPump,
        everyElement(lessThanOrEqualTo(_snapshotsPerGap)),
        reason: '$perPump',
      );
      expect(perPump, contains(_snapshotsPerGap), reason: '$perPump');
    },
  );
}
