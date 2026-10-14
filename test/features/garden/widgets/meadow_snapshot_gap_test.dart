import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:field_notes/features/garden/render/meadow_layers.dart';
import 'package:field_notes/features/garden/render/meadow_rays.dart';
import 'package:field_notes/features/garden/render/meadow_stage_painter.dart';
import 'package:field_notes/features/garden/scene/meadow_pacer.dart';
import 'package:field_notes/features/garden/scene/meadow_stage.dart';
import 'package:field_notes/features/garden/scene/meadow_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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

List<ui.Image> _recolouredImages(MeadowStagePainter painter) {
  final MeadowLayers layers = painter.layers;
  return <ui.Image>[
    layers.mountains.image,
    for (final MeadowImage tile in layers.water) tile.image,
    for (final MeadowFallLayer fall in layers.falls) ...<ui.Image>[
      fall.body.image,
      fall.pool.image,
      for (final MeadowStreakStrip streak in fall.streaks) streak.tile,
    ],
    for (final MeadowCloudImage cloud in layers.clouds) cloud.image.image,
  ];
}

void _fillGap() {
  for (int i = 0; i < _snapshotsPerGap; i++) {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    ui.Canvas(recorder, const ui.Rect.fromLTWH(0, 0, 1, 1));
    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = meadowSnapshot(picture, 1, 1);
    picture.dispose();
    addTearDown(image.dispose);
  }
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

  testWidgets(
    'a recolour on an open meadow fills each frame gap, waits for the next '
    'past the room or half a frame, and redraws every part',
    (WidgetTester tester) async {
      useStageGpu(stepMs: 12);
      const Key slowKey = ValueKey<String>('filled gap stage');
      MeadowStageState state = await _openAtNoon(tester, slowKey);
      final MeadowStagePainter noon = _stagePainter(tester);
      final ui.Image noonRays = noon.rays.image;
      final List<ui.Image> noonPieces = _recolouredImages(noon);

      final ImageCount count = _countImages();
      final List<int> perPump = <int>[];
      int before = count.created;
      state = await pumpMeadowStage(
        tester,
        stageKey: slowKey,
        sky: meadowMidnight,
        tickers: false,
      );
      perPump.add(count.created - before);
      _fillGap();
      expect(meadowPacer.snapshotRoom, 0, reason: 'the frame gap is full');
      final int revision = _stagePainter(tester).raysRevision;

      before = count.created;
      await tester.pump();
      perPump.add(count.created - before);
      expect(perPump.last, 0, reason: 'nothing renders in a full gap');
      expect(
        _stagePainter(tester).raysRevision,
        revision,
        reason: 'the rays wait for the next gap',
      );

      before = count.created;
      await tester.pump();
      perPump.add(count.created - before);
      expect(perPump.last, _snapshotsPerGap, reason: 'the next gap is filled');
      expect(_stagePainter(tester).raysRevision, revision + 1);

      int pumps = 2;
      while (state.debugIsRecolouring && pumps < 64) {
        before = count.created;
        await tester.pump();
        pumps++;
        perPump.add(count.created - before);
      }
      expect(state.debugIsRecolouring, isFalse, reason: '$pumps pumps');
      expect(
        perPump,
        everyElement(lessThanOrEqualTo(_snapshotsPerGap)),
        reason: '$perPump',
      );

      final MeadowStagePainter midnight = _stagePainter(tester);
      expect(midnight.rays.image, isNot(same(noonRays)));
      final List<ui.Image> midnightPieces = _recolouredImages(midnight);
      expect(midnightPieces, hasLength(noonPieces.length));
      for (int i = 0; i < noonPieces.length; i++) {
        expect(
          midnightPieces[i],
          isNot(same(noonPieces[i])),
          reason: 'recoloured image $i',
        );
      }
      final MeadowRays fresh = MeadowRays(midnight.palette)..buildAll();
      addTearDown(fresh.dispose);
      expect(
        await _bytesOf(tester, midnight.rays.image),
        await _bytesOf(tester, fresh.image),
      );
      await tester.pumpWidget(const SizedBox());

      final StageGpu busy = useStageGpu(stepMs: 0.1);
      const Key busyKey = ValueKey<String>('busy gap stage');
      state = await _openAtNoon(tester, busyKey);
      busy.busyStage = state;
      int pieces = state.debugRecolourPieces;
      state = await pumpMeadowStage(
        tester,
        stageKey: busyKey,
        sky: meadowMidnight,
        tickers: false,
      );
      final List<int> drawn = <int>[state.debugRecolourPieces - pieces];
      int threes = 0;
      pumps = 0;
      while (state.debugIsRecolouring && pumps < 64) {
        pieces = state.debugRecolourPieces;
        final int raysRevision = _stagePainter(tester).raysRevision;
        await tester.pump();
        pumps++;
        drawn.add(state.debugRecolourPieces - pieces);
        if (drawn.last == 3 &&
            _stagePainter(tester).raysRevision == raysRevision) {
          threes++;
        }
      }
      expect(state.debugIsRecolouring, isFalse, reason: '$pumps pumps');
      expect(drawn, everyElement(lessThanOrEqualTo(3)), reason: '$drawn');
      expect(threes, greaterThan(0), reason: '$drawn');
    },
  );

  testWidgets(
    'work on frames sends no marker and fills the room whatever the learned '
    'estimate',
    (WidgetTester tester) async {
      final StageGpu quick = useStageGpu(stepMs: 0.1);
      final ImageCount count = _countImages();
      const Key key = ValueKey<String>('framed work stage');
      MeadowStageState state = await pumpMeadowStage(
        tester,
        stageKey: key,
        sky: meadowNoon,
        tickers: false,
      );
      await _growOnFrames(tester, state, count);
      state = await pumpMeadowStage(
        tester,
        stageKey: key,
        sky: meadowMidnight,
        tickers: false,
      );
      for (int i = 0; i < 64 && state.debugIsRecolouring; i++) {
        await tester.pump();
      }
      expect(state.debugIsRecolouring, isFalse);
      expect(quick.markers, 0, reason: 'no marker for work on frames');
      expect(quick.sent, isNotEmpty);
      for (final StageBatch batch in quick.sent) {
        expect(batch.phase, isNot(SchedulerPhase.idle), reason: '$batch');
      }
      expect(
        quick.sent.map((StageBatch batch) => batch.kind).toSet(),
        containsAll(MeadowWork.values),
      );
      for (final MeadowWork kind in MeadowWork.values) {
        expect(quick.estimateOf(kind), isNull, reason: '$kind');
      }
      await tester.pumpWidget(const SizedBox());

      final StageGpu slow = useStageGpu(stepMs: 12);
      const double ratio = 2;
      state = await pumpMeadowStage(
        tester,
        year: meadowLeapYear(),
        ratio: ratio,
        tickers: false,
      );
      await growMeadow(tester, state);
      expect(
        slow.estimateOf(MeadowWork.layers),
        const Duration(microseconds: 12000),
      );
      expect(
        slow.allowance(
          MeadowWork.layers,
          share: const Duration(microseconds: 16667),
        ),
        1,
      );
      final double screen =
          MeadowViewport.resolve(
            box: meadowSidebarCard,
            cover: false,
            focusX: 0,
          ).scale *
          ratio;
      bool sharp() =>
          (_stagePainter(tester).layers.density - screen).abs() < 1e-9;
      final int markers = slow.markers;
      final int shown = slow.sent.length;
      final List<int> perPump = <int>[];
      for (int i = 0; i < meadowBuildFrames && !sharp(); i++) {
        final int before = count.created;
        await tester.pump(const Duration(milliseconds: 16));
        perPump.add(count.created - before);
      }
      expect(sharp(), isTrue, reason: 'the meadow never sharpened');
      expect(slow.markers, markers, reason: 'no marker during the sharpen');
      final List<StageBatch> sharpening = slow.sent.sublist(shown);
      expect(sharpening, isNotEmpty);
      for (final StageBatch batch in sharpening) {
        expect(batch.phase, isNot(SchedulerPhase.idle), reason: '$batch');
      }
      expect(
        perPump,
        everyElement(lessThanOrEqualTo(_snapshotsPerGap)),
        reason: '$perPump',
      );
      expect(perPump, contains(_snapshotsPerGap), reason: '$perPump');
    },
  );
}
