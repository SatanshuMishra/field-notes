import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:field_notes/features/capture/immersive/immersive.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const Size _size = Size(370, 370);
const double _orbRadius = 62;
const Offset _centre = Offset(185, 185);
const Duration _frame = Duration(milliseconds: 16);

class _PickRandom implements math.Random {
  _PickRandom({this.draw = 0, List<int> picks = const <int>[]})
    : _picks = List<int>.of(picks);

  final double draw;
  final List<int> _picks;

  @override
  double nextDouble() => draw;

  @override
  int nextInt(int max) => _picks.isEmpty ? 0 : _picks.removeAt(0);

  @override
  bool nextBool() => false;
}

class _Line {
  const _Line(this.start, this.end, this.color, this.width, this.cap);

  final Offset start;
  final Offset end;
  final Color color;
  final double width;
  final StrokeCap cap;
}

class _RecordingCanvas extends Fake implements Canvas {
  final List<_Line> lines = <_Line>[];
  final List<Offset> circles = <Offset>[];
  int paths = 0;

  @override
  void clipRect(
    Rect rect, {
    ui.ClipOp clipOp = ui.ClipOp.intersect,
    bool doAntiAlias = true,
  }) {}

  @override
  void drawPath(Path path, Paint paint) {
    paths++;
  }

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) {
    lines.add(_Line(p1, p2, paint.color, paint.strokeWidth, paint.strokeCap));
  }

  @override
  void drawCircle(Offset c, double radius, Paint paint) {
    circles.add(c);
  }
}

VoiceLevelSmoother _steadyAt(double level) {
  final VoiceLevelSmoother smoother = VoiceLevelSmoother();
  smoother.hear(level, Duration.zero);
  for (int step = 0; step < 3; step++) {
    smoother.advance(1);
  }
  return smoother;
}

CometsModel _cometsModel({
  required VoiceLevelStage stage,
  math.Random? random,
  VoiceLevelSmoother? smoother,
  bool still = false,
}) {
  return CometsModel(
    size: _size,
    orbRadius: _orbRadius,
    random: random ?? _PickRandom(),
    stage: stage,
    smoother: smoother,
    still: still,
  );
}

Widget _layer({
  required VoiceLevelStage stage,
  Stream<double> levels = const Stream<double>.empty(),
  math.Random? random,
  bool still = false,
}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: still),
    child: Center(
      child: SizedBox(
        width: 370,
        height: 370,
        child: VoiceLevelField(
          levels: levels,
          stage: stage,
          orbRadius: _orbRadius,
          random: random,
        ),
      ),
    ),
  );
}

CometsModel _layerModel(WidgetTester tester) =>
    tester.state<VoiceLevelFieldState>(find.byType(VoiceLevelField)).model!;

int _bornCount(CometsModel model) =>
    model.comets.where((Comet comet) => comet.isBorn).length;

CometTrailPoint _trailPoint(
  Offset offset,
  double time, {
  double depth = 4,
  bool hidden = false,
}) {
  return CometTrailPoint(
    point: CometPoint(offset: offset, depth: depth, hidden: hidden),
    time: time,
  );
}

int _rgb(Color color) => color.toARGB32() & 0x00FFFFFF;

double _restStep(int index, double angle, double dt) {
  final double a = 74 + 105 * (0.45 + 0.12 * index);
  final double e = 0.38 + 0.06 * index;
  final double r = a * (1 - e * e) / (1 + e * math.cos(angle));
  return 0.5 * 0.35 * math.pow(a / r, 1.6) * dt;
}

Future<Uint8List> _pixels(WidgetTester tester, CometsModel model) async {
  final GlobalKey boundaryKey = GlobalKey();
  await tester.pumpWidget(
    Center(
      child: RepaintBoundary(
        key: boundaryKey,
        child: SizedBox(
          width: 370,
          height: 370,
          child: CustomPaint(painter: CometsPainter(model: model)),
        ),
      ),
    ),
  );
  final RenderRepaintBoundary boundary =
      boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final ByteData? bytes = await tester.runAsync<ByteData?>(() async {
    final ui.Image image = await boundary.toImage();
    try {
      expect(image.width, 370);
      expect(image.height, 370);
      return await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    } finally {
      image.dispose();
    }
  });
  return bytes!.buffer.asUint8List();
}

int _alphaAt(Uint8List rgba, int x, int y) => rgba[(y * 370 + x) * 4 + 3];

void main() {
  test('each comet starts on its own ellipse', () {
    final CometsModel model = _cometsModel(
      stage: VoiceLevelStage.recording,
      still: true,
    );
    model.advance(0);
    final _RecordingCanvas canvas = _RecordingCanvas();
    CometsPainter(model: model).paint(canvas, _size);

    expect(model.comets, hasLength(4));
    final List<Offset> shown = <Offset>[];
    for (int i = 0; i < 4; i++) {
      final Comet comet = model.comets[i];
      final double a = 74 + 105 * (0.45 + 0.12 * i);
      final double e = 0.38 + 0.06 * i;
      final double theta = 1.7 * i;
      final double ti = 1.0 + 0.12 * i;
      final double om = 1.6 * i - 1.2;
      final double r = a * (1 - e * e) / (1 + e * math.cos(theta));
      final double x = r * math.cos(theta);
      final double y = r * math.sin(theta) * math.cos(ti);
      final double z = r * math.sin(theta) * math.sin(ti);
      final Offset expected = Offset(
        185 + x * math.cos(om) - y * math.sin(om),
        185 + x * math.sin(om) + y * math.cos(om),
      );

      expect(comet.semiMajor, closeTo(a, 1e-9), reason: 'comet $i');
      expect(comet.eccentricity, closeTo(e, 1e-12), reason: 'comet $i');
      expect(comet.angle, closeTo(theta, 1e-12), reason: 'comet $i');
      expect(comet.tilt, closeTo(ti, 1e-12), reason: 'comet $i');
      expect(comet.turn, closeTo(om, 1e-12), reason: 'comet $i');
      expect(comet.point.offset.dx, closeTo(expected.dx, 1e-6));
      expect(comet.point.offset.dy, closeTo(expected.dy, 1e-6));
      expect(comet.point.depth, closeTo(z, 1e-6), reason: 'comet $i');
      final bool hidden = z < 0 && (expected - _centre).distance < 62 + 1;
      expect(comet.point.hidden, hidden, reason: 'comet $i');
      if (!hidden) {
        shown.add(expected);
      }
    }
    expect(shown, isNotEmpty);
    expect(canvas.circles, hasLength(shown.length));
    for (int head = 0; head < shown.length; head++) {
      expect(canvas.circles[head].dx, closeTo(shown[head].dx, 1e-6));
      expect(canvas.circles[head].dy, closeTo(shown[head].dy, 1e-6));
    }
  });

  test('a comet moves faster near the orb and with the voice', () {
    final List<double> steps = <double>[];
    for (final double level in <double>[0, 0.5, 1]) {
      final CometsModel model = _cometsModel(
        stage: VoiceLevelStage.recording,
        smoother: _steadyAt(level),
      );
      model.advance(0);
      model.advance(1.2);
      final Comet comet = model.comets[0];
      expect(model.level, level);
      expect(comet.brightness, 0);
      expect(comet.ease, 1);

      final double before = comet.angle;
      model.advance(1 / 60);
      const double a = 74 + 105 * 0.45;
      const double e = 0.38;
      final double r = a * (1 - e * e) / (1 + e * math.cos(before));
      final double expected =
          0.5 * (0.35 + 2.4 * level) * math.pow(a / r, 1.6) / 60;

      expect(comet.angle - before, closeTo(expected, 1e-9), reason: '$level');
      steps.add(comet.angle - before);
    }
    expect(steps[1], greaterThan(steps[0]));
    expect(steps[2], greaterThan(steps[1]));
  });

  test('a comet behind the orb is hidden', () {
    final CometPoint behindInside = projectCometPoint(
      centre: _centre,
      orbRadius: _orbRadius,
      radius: 40,
      angle: -math.pi / 2,
      tilt: 1,
      turn: 0,
    );
    final CometPoint behindOutside = projectCometPoint(
      centre: _centre,
      orbRadius: _orbRadius,
      radius: 100,
      angle: -math.pi / 2,
      tilt: 0.3,
      turn: 0,
    );
    final CometPoint frontInside = projectCometPoint(
      centre: _centre,
      orbRadius: _orbRadius,
      radius: 40,
      angle: math.pi / 2,
      tilt: 1,
      turn: 0,
    );
    final CometPoint levelInside = projectCometPoint(
      centre: _centre,
      orbRadius: _orbRadius,
      radius: 40,
      angle: 0,
      tilt: 1,
      turn: 0,
    );

    expect(behindInside.depth, lessThan(0));
    expect((behindInside.offset - _centre).distance, lessThan(63));
    expect(behindInside.hidden, isTrue);

    expect(behindOutside.depth, lessThan(0));
    expect((behindOutside.offset - _centre).distance, greaterThan(63));
    expect(behindOutside.hidden, isFalse);

    expect(frontInside.depth, greaterThanOrEqualTo(0));
    expect((frontInside.offset - _centre).distance, lessThan(63));
    expect(frontInside.hidden, isFalse);

    expect(levelInside.depth, 0);
    expect((levelInside.offset - _centre).distance, lessThan(63));
    expect(levelInside.hidden, isFalse);
  });

  test('an onset brightens one comet and it fades', () {
    final CometsModel model = _cometsModel(
      stage: VoiceLevelStage.recording,
      random: _PickRandom(picks: <int>[2, 0]),
    );
    model.advance(0);

    model.hear(0.6);
    expect(model.comets[2].brightness, 0.6);
    for (final int other in <int>[0, 1, 3]) {
      expect(model.comets[other].brightness, 0, reason: 'comet $other');
    }

    model.advance(0.5);
    expect(model.comets[2].brightness, closeTo(0.6 * math.exp(-0.8), 1e-12));
    for (final int other in <int>[0, 1, 3]) {
      expect(model.comets[other].brightness, 0, reason: 'comet $other');
    }
  });

  test('brightness stops at 1', () {
    final CometsModel model = _cometsModel(
      stage: VoiceLevelStage.recording,
      random: _PickRandom(picks: <int>[2, 0, 2, 0]),
    );
    model.advance(0);
    model.onset(0.7);
    expect(model.comets[2].brightness, 0.7);

    model.onset(0.6);
    expect(model.comets[2].brightness, 1);
  });

  test('with no onset brightness only fades', () {
    final CometsModel model = _cometsModel(
      stage: VoiceLevelStage.recording,
      random: _PickRandom(picks: <int>[1, 0]),
    );
    model.advance(0);
    model.onset(0.5);
    expect(model.comets[1].brightness, 0.5);

    model.advance(1);
    expect(model.comets[1].brightness, closeTo(0.5 * math.exp(-1.6), 1e-12));
  });

  test('a trail fades and thins with age', () {
    final List<CometTrailSegment> segments = cometTrailSegments(
      trail: <CometTrailPoint>[
        _trailPoint(const Offset(300, 40), 9.35),
        _trailPoint(const Offset(310, 40), 9.55),
        _trailPoint(const Offset(320, 40), 10),
      ],
      now: 10,
      brightness: 0,
      level: 0,
      ease: 1,
    );

    expect(segments, hasLength(2));
    final CometTrailSegment fresh = segments[1];
    final CometTrailSegment half = segments[0];
    expect(fresh.color.a, closeTo(0.8 * 1, 1e-9));
    expect(half.color.a, closeTo(0.8 * math.pow(0.5, 1.5), 1e-9));
    expect(fresh.width, closeTo(0.6, 1e-9));
    expect(half.width, closeTo(0.6 * 0.65, 1e-9));
    expect(_rgb(fresh.color), 0xF3E6D1);
    expect(_rgb(half.color), 0xF3E6D1);
    expect(fresh.start, const Offset(310, 40));
    expect(fresh.end, const Offset(320, 40));

    final CometsModel model = _cometsModel(
      stage: VoiceLevelStage.recording,
      smoother: _steadyAt(0),
    );
    model.advance(0);
    model.advance(1.2);
    for (int frame = 0; frame < 10; frame++) {
      model.advance(1 / 60);
    }
    final _RecordingCanvas canvas = _RecordingCanvas();
    CometsPainter(model: model).paint(canvas, _size);
    expect(canvas.lines.length, greaterThan(32));
    for (final _Line line in canvas.lines) {
      expect(line.cap, StrokeCap.round);
    }
  });

  test('a bright comet glows pink with a bigger head', () {
    final CometsModel model = _cometsModel(
      stage: VoiceLevelStage.recording,
      random: _PickRandom(picks: <int>[0, 0]),
      smoother: _steadyAt(0.2),
    );
    model.advance(0);
    model.advance(1.2);
    for (int frame = 0; frame < 6; frame++) {
      model.advance(1 / 60);
    }
    model.onset(0.5);
    final Comet comet = model.comets[0];
    expect(comet.brightness, 0.5);
    expect(comet.ease, 1);
    expect(model.level, 0.2);
    expect(comet.trail.last.point.depth, greaterThanOrEqualTo(0));
    expect(comet.trail.last.time, model.time);

    final CometTrailSegment newest = comet.segments.last;
    expect(_rgb(newest.color), 0xE58D9C);
    expect(newest.color.a, closeTo(1, 1e-9));
    final CometHead head = comet.head!;
    expect(head.radius, closeTo(2.5, 1e-12));
    expect(head.color.toARGB32(), const Color(0xFFF3E6D1).toARGB32());
    expect(comet.trailSpan, closeTo(1.3, 1e-12));
  });

  test('the far side is dimmer and hidden ends are skipped', () {
    final List<CometTrailSegment> farSide = cometTrailSegments(
      trail: <CometTrailPoint>[
        _trailPoint(const Offset(300, 40), 9.9, depth: -4),
        _trailPoint(const Offset(310, 40), 10, depth: -4),
      ],
      now: 10,
      brightness: 0.5,
      level: 0,
      ease: 1,
    );
    expect(farSide, hasLength(1));
    expect(farSide.single.color.a, closeTo(0.45 * 1, 1e-9));
    expect(_rgb(farSide.single.color), 0xE58D9C);

    final List<CometTrailSegment> skipped = cometTrailSegments(
      trail: <CometTrailPoint>[
        _trailPoint(const Offset(300, 40), 9.7),
        _trailPoint(_centre, 9.8, depth: -4, hidden: true),
        _trailPoint(const Offset(310, 40), 9.9),
        _trailPoint(const Offset(320, 40), 10),
      ],
      now: 10,
      brightness: 0.5,
      level: 0,
      ease: 1,
    );
    expect(skipped, hasLength(1));
    expect(skipped.single.start, const Offset(310, 40));
    expect(skipped.single.end, const Offset(320, 40));

    final CometsModel model = _cometsModel(
      stage: VoiceLevelStage.recording,
      smoother: _steadyAt(0),
    );
    model.advance(0);
    for (int frame = 0; frame < 120; frame++) {
      model.advance(1 / 60);
    }
    final Comet comet = model.comets[0];
    expect(comet.brightness, 0);
    expect(comet.trailSpan, closeTo(0.9, 1e-12));
    expect(comet.trail.length, greaterThan(1));
    for (final CometTrailPoint point in comet.trail) {
      expect(model.time - point.time, lessThanOrEqualTo(0.9 + 1e-9));
    }
    expect(
      model.time - comet.trail.first.time,
      greaterThan(0.9 - 1 / 60 - 1e-9),
    );
  });

  testWidgets('the glow ring leaves the orb clear', (
    WidgetTester tester,
  ) async {
    final CometsModel model = _cometsModel(
      stage: VoiceLevelStage.recording,
      smoother: _steadyAt(0.5),
    );
    expect(model.time, 0);
    expect(model.level, 0.5);

    final Uint8List rgba = await _pixels(tester, model);

    expect(_alphaAt(rgba, 185, 185), 0);
    expect(_alphaAt(rgba, 124, 184), 0);
    expect(_alphaAt(rgba, 125, 184), 0);
    expect(_alphaAt(rgba, 121, 184), closeTo((0.14 + 0.14 + 0.025) * 255, 4));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the glow reaches further with the voice', (
    WidgetTester tester,
  ) async {
    final CometsModel quiet = _cometsModel(
      stage: VoiceLevelStage.recording,
      smoother: _steadyAt(0),
    );
    final CometsModel loud = _cometsModel(
      stage: VoiceLevelStage.recording,
      smoother: _steadyAt(1),
    );
    expect(quiet.glow.outer, closeTo(74 + 105 * 0.5, 1e-9));
    expect(loud.glow.outer, closeTo(74 + 105, 1e-9));

    final Uint8List quietPixels = await _pixels(tester, quiet);
    expect(_alphaAt(quietPixels, 185, 54), 0);

    final Uint8List loudPixels = await _pixels(tester, loud);
    expect(_alphaAt(loudPixels, 185, 54), greaterThan(0));
    expect(_alphaAt(loudPixels, 185, 3), 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('sixteen stars sit in the ring around the orb', () {
    final CometsModel model = _cometsModel(
      stage: VoiceLevelStage.recording,
      random: math.Random(11),
    );
    final _RecordingCanvas canvas = _RecordingCanvas();
    CometsPainter(model: model).paint(canvas, _size);

    expect(model.stars, hasLength(16));
    expect(canvas.lines, hasLength(32));
    for (int star = 0; star < 16; star++) {
      final _Line across = canvas.lines[2 * star];
      final _Line down = canvas.lines[2 * star + 1];
      final Offset centre = Offset.lerp(across.start, across.end, 0.5)!;
      expect(across.start.dy, across.end.dy);
      expect(down.start.dx, down.end.dx);
      expect(
        Offset.lerp(down.start, down.end, 0.5)!,
        offsetMoreOrLessEquals(centre),
      );
      final double arm = (across.end.dx - across.start.dx) / 2;
      expect((down.end.dy - down.start.dy) / 2, closeTo(arm, 1e-9));
      expect(arm, inInclusiveRange(0.6 * 1.6, 2.0 * 1.6), reason: '$star');
      expect(
        (centre - _centre).distance,
        inInclusiveRange(86 - 1e-9, 74 + 1.1 * 105 + 1e-9),
        reason: 'star $star',
      );
      for (final _Line line in <_Line>[across, down]) {
        expect(line.width, 1);
        expect(line.cap, StrokeCap.round);
        expect(_rgb(line.color), 0xF3E6D1);
      }
      expect(model.stars[star].flash, 0);
    }
  });

  test('a loud onset lights one star', () {
    final CometsModel model = _cometsModel(
      stage: VoiceLevelStage.recording,
      random: _PickRandom(draw: 0.5, picks: <int>[0, 5]),
    );
    model.advance(0);
    final double unlitArm = model.stars[4].arm;
    expect(unlitArm, closeTo(1.3 * 1.6, 1e-9));

    model.onset(0.6);
    final CometStar star = model.stars[5];
    expect(star.flash, 1);
    for (int other = 0; other < 16; other++) {
      if (other != 5) {
        expect(model.stars[other].flash, 0, reason: 'star $other');
      }
    }
    expect(
      star.alpha,
      closeTo(0.18 + 0.1 * math.sin(1.3 * math.pi) + 0.8 * 1, 1e-9),
    );
    expect(star.arm, closeTo(1.3 * (1.6 + 3.5 * 1), 1e-9));
    expect(star.arm - unlitArm, closeTo(3.5 * 1 * 1.3, 1e-9));

    model.advance(0.5);
    final double f = math.exp(-1.1);
    expect(star.flash, closeTo(f, 1e-12));
    expect(
      star.alpha,
      closeTo(0.18 + 0.1 * math.sin(1.3 * (math.pi + 0.5)) + 0.8 * f, 1e-9),
    );
    expect(star.arm, closeTo(1.3 * (1.6 + 3.5 * f), 1e-9));
    expect(star.arm - model.stars[4].arm, closeTo(3.5 * f * 1.3, 1e-9));
  });

  test('a soft onset lights nothing', () {
    final CometsModel model = _cometsModel(
      stage: VoiceLevelStage.recording,
      random: _PickRandom(draw: 0.5, picks: <int>[0, 3]),
    );
    model.advance(0);

    model.onset(0.45);
    expect(model.comets[0].brightness, 0.45);
    for (final CometStar star in model.stars) {
      expect(star.flash, 0);
    }
  });

  testWidgets('comets arrive a second apart through the breath', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _layer(stage: VoiceLevelStage.breathing, random: math.Random(5)),
    );
    await tester.pump();
    final CometsModel model = _layerModel(tester);
    expect(_bornCount(model), 1);

    await tester.pump(const Duration(milliseconds: 1000));
    expect(_bornCount(model), 2);

    await tester.pump(const Duration(milliseconds: 1000));
    expect(_bornCount(model), 3);

    await tester.pump(const Duration(milliseconds: 1000));
    expect(_bornCount(model), 3);
    expect(model.comets[3].isBorn, isFalse);

    await tester.pumpWidget(
      _layer(stage: VoiceLevelStage.recording, random: math.Random(5)),
    );
    expect(_bornCount(model), 4);
    expect(model.comets[3].born, closeTo(3, 1e-9));
    expect(model.comets[3].born, closeTo(model.time, 1e-9));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a layer first shown while recording has all four comets', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _layer(stage: VoiceLevelStage.recording, random: math.Random(5)),
    );
    expect(_bornCount(_layerModel(tester)), 0);

    await tester.pump();
    final CometsModel model = _layerModel(tester);
    expect(_bornCount(model), 4);
    for (final Comet comet in model.comets) {
      expect(comet.born, 0);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('a comet flies in over 1.1 s', () {
    final CometsModel model = _cometsModel(stage: VoiceLevelStage.breathing);
    model.advance(0);
    model.advance(1.0);
    final Comet comet = model.comets[1];
    expect(comet.born, 1.0);

    expect(comet.radiusFactor, closeTo(2.4, 1e-9));
    expect(comet.ease, closeTo(0, 1e-9));

    model.advance(0.55);
    expect(comet.radiusFactor, closeTo(1 + 1.4 * 0.125, 1e-9));
    expect(comet.ease, closeTo(0.875, 1e-9));
    final double halfShare = comet.trail.last.point.depth < 0 ? 0.45 : 1;
    expect(comet.segments.last.color.a, closeTo(0.8 * halfShare * 0.875, 1e-9));

    model.advance(0.55);
    expect(comet.radiusFactor, closeTo(1, 1e-9));
    expect(comet.ease, closeTo(1, 1e-9));
    final double doneShare = comet.trail.last.point.depth < 0 ? 0.45 : 1;
    expect(comet.segments.last.color.a, closeTo(0.8 * doneShare * 1, 1e-9));
  });

  testWidgets('the level stays 0 through the breath', (
    WidgetTester tester,
  ) async {
    final StreamController<double> levels =
        StreamController<double>.broadcast();
    await tester.pumpWidget(
      _layer(
        stage: VoiceLevelStage.breathing,
        levels: levels.stream,
        random: math.Random(5),
      ),
    );
    await tester.pump();
    final CometsModel model = _layerModel(tester);

    for (int frame = 0; frame < 125; frame++) {
      levels.add(0.9);
      await tester.pump(_frame);
    }

    expect(model.time, closeTo(2, 1e-9));
    expect(model.level, 0);
    for (final Comet comet in model.comets) {
      expect(comet.brightness, 0);
    }
    for (final CometStar star in model.stars) {
      expect(star.flash, 0);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await levels.close();
  });

  test('a paused layer falls to rest and keeps moving', () {
    final CometsModel model = _cometsModel(
      stage: VoiceLevelStage.recording,
      random: _PickRandom(draw: 0.5, picks: <int>[1, 3, 2, 7]),
      smoother: _steadyAt(0.8),
    );
    model.advance(0);
    model.onset(0.8);
    model.onset(0.8);
    model.advance(1 / 60);
    expect(model.level, 0.8);
    expect(model.comets[1].brightness, greaterThan(0));
    expect(model.stars[3].flash, greaterThan(0));

    model.stage = VoiceLevelStage.paused;
    for (int frame = 1; frame <= 180; frame++) {
      final List<double> angles = <double>[
        for (final Comet comet in model.comets) comet.angle,
      ];
      final List<double> brightness = <double>[
        for (final Comet comet in model.comets) comet.brightness,
      ];
      final List<double> flashes = <double>[
        for (final CometStar star in model.stars) star.flash,
      ];
      model.hear(0.8);
      model.advance(1 / 60);

      expect(
        model.level,
        closeTo(0.8 * math.pow(1 - 0.085, frame), 1e-12),
        reason: 'frame $frame',
      );
      for (int index = 0; index < 4; index++) {
        expect(model.comets[index].angle, greaterThan(angles[index]));
        expect(
          model.comets[index].brightness,
          lessThanOrEqualTo(brightness[index]),
        );
      }
      for (int index = 0; index < 16; index++) {
        expect(model.stars[index].flash, lessThanOrEqualTo(flashes[index]));
      }
    }
    expect(model.level, closeTo(0.8 * math.pow(0.915, 180), 1e-12));
  });

  test('resuming follows the voice again', () {
    final CometsModel model = _cometsModel(
      stage: VoiceLevelStage.recording,
      smoother: _steadyAt(0.8),
    );
    model.advance(0);
    model.stage = VoiceLevelStage.paused;
    for (int frame = 0; frame < 180; frame++) {
      model.hear(0.8);
      model.advance(1 / 60);
    }
    final double paused = 0.8 * math.pow(0.915, 180);
    expect(model.level, closeTo(paused, 1e-12));

    model.stage = VoiceLevelStage.recording;
    model.hear(0.8);
    model.advance(1 / 60);
    expect(model.level, closeTo(paused + (0.8 - paused) * 0.32, 1e-12));

    for (int frame = 2; frame <= 60; frame++) {
      model.hear(0.8);
      model.advance(1 / 60);
    }
    expect(
      model.level,
      closeTo(0.8 - (0.8 - paused) * math.pow(1 - 0.32, 60), 1e-12),
    );
  });

  test('a steady voice across a pause fires no onset on resume', () {
    final CometsModel model = CometsModel(
      size: const Size(370, 370),
      orbRadius: 62,
      random: math.Random(5),
      stage: VoiceLevelStage.recording,
    );
    List<double> brightness() => <double>[
      for (final Comet comet in model.comets) comet.brightness,
    ];
    List<double> flashes() => <double>[
      for (final CometStar star in model.stars) star.flash,
    ];

    for (int frame = 0; frame < 120; frame++) {
      model.hear(0.5);
      model.advance(1 / 60);
    }
    model.stage = VoiceLevelStage.paused;
    for (int frame = 0; frame < 120; frame++) {
      model.advance(1 / 60);
    }
    model.stage = VoiceLevelStage.recording;
    final List<double> brightnessBefore = brightness();
    final List<double> flashesBefore = flashes();

    model.hear(0.5);

    expect(brightness(), brightnessBefore);
    expect(flashes(), flashesBefore);
  });

  test(
    'after a pause the first level is measured from the level before it',
    () {
      final CometsModel model = CometsModel(
        size: const Size(370, 370),
        orbRadius: 62,
        random: math.Random(5),
        stage: VoiceLevelStage.recording,
      );
      List<double> brightness() => <double>[
        for (final Comet comet in model.comets) comet.brightness,
      ];
      List<double> flashes() => <double>[
        for (final CometStar star in model.stars) star.flash,
      ];
      List<int> changed(List<double> before, List<double> after) => <int>[
        for (int index = 0; index < after.length; index++)
          if (after[index] != before[index]) index,
      ];
      void pauseForTwoSeconds() {
        model.stage = VoiceLevelStage.paused;
        for (int frame = 0; frame < 120; frame++) {
          model.advance(1 / 60);
        }
      }

      model.stage = VoiceLevelStage.paused;
      model.stage = VoiceLevelStage.recording;
      final List<double> firstBrightness = brightness();
      final List<double> firstFlashes = flashes();
      model.hear(0.3);
      final List<double> firstRaised = brightness();
      final List<int> firstComets = changed(firstBrightness, firstRaised);
      expect(firstComets, hasLength(1));
      expect(
        firstRaised[firstComets.single] - firstBrightness[firstComets.single],
        closeTo(0.3, 1e-12),
      );
      expect(flashes(), firstFlashes);

      for (int frame = 0; frame < 120; frame++) {
        model.hear(0.3);
        model.advance(1 / 60);
      }
      pauseForTwoSeconds();
      model.stage = VoiceLevelStage.recording;
      final List<double> steadyBrightness = brightness();
      final List<double> steadyFlashes = flashes();
      model.hear(0.3);
      expect(brightness(), steadyBrightness);
      expect(flashes(), steadyFlashes);

      pauseForTwoSeconds();
      model.stage = VoiceLevelStage.recording;
      final List<double> louderBrightness = brightness();
      final List<double> louderFlashes = flashes();
      model.hear(0.6);
      final List<double> louderRaised = brightness();
      final List<int> louderComets = changed(louderBrightness, louderRaised);
      expect(louderComets, hasLength(1));
      expect(
        louderRaised[louderComets.single] -
            louderBrightness[louderComets.single],
        closeTo(0.6, 1e-12),
      );
      final List<double> louderLit = flashes();
      final List<int> louderStars = changed(louderFlashes, louderLit);
      expect(louderStars, hasLength(1));
      expect(louderLit[louderStars.single], 1);
    },
  );

  testWidgets('with reduced motion comets rest and stars hold still', (
    WidgetTester tester,
  ) async {
    final StreamController<double> levels =
        StreamController<double>.broadcast();
    await tester.pumpWidget(
      _layer(
        stage: VoiceLevelStage.breathing,
        levels: levels.stream,
        random: math.Random(5),
        still: true,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    final CometsModel model = _layerModel(tester);
    expect(_bornCount(model), 2);
    for (final Comet comet in model.comets.where((Comet c) => c.isBorn)) {
      expect(comet.ease, 1);
      expect(comet.radiusFactor, 1);
    }

    await tester.pumpWidget(
      _layer(
        stage: VoiceLevelStage.recording,
        levels: levels.stream,
        random: math.Random(5),
        still: true,
      ),
    );
    for (int frame = 0; frame < 40; frame++) {
      levels.add(0.9);
      await tester.pump(_frame);
    }
    model.onset(0.8);
    model.onset(0.8);
    expect(_bornCount(model), 4);
    expect(model.level, greaterThan(0.5));
    expect(model.comets.any((Comet comet) => comet.brightness > 0.5), isTrue);

    final List<double> angles = <double>[
      for (final Comet comet in model.comets) comet.angle,
    ];
    final List<double> alphas = <double>[
      for (final CometStar star in model.stars) star.alpha,
    ];
    final List<double> arms = <double>[
      for (final CometStar star in model.stars) star.arm,
    ];
    levels.add(0.9);
    await tester.pump(_frame);

    for (int index = 0; index < 4; index++) {
      final Comet comet = model.comets[index];
      expect(comet.ease, 1);
      expect(
        comet.angle - angles[index],
        closeTo(_restStep(index, angles[index], 0.016), 1e-9),
        reason: 'comet $index',
      );
    }
    for (int index = 0; index < 16; index++) {
      expect(model.stars[index].alpha, alphas[index]);
      expect(model.stars[index].arm, arms[index]);
      expect(model.stars[index].flash, 0);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await levels.close();
  });

  testWidgets('with animations on the stars twinkle', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _layer(stage: VoiceLevelStage.recording, random: math.Random(5)),
    );
    await tester.pump();
    final CometsModel model = _layerModel(tester);
    final List<double> before = <double>[
      for (final CometStar star in model.stars) star.alpha,
    ];

    await tester.pump(const Duration(milliseconds: 500));

    for (int index = 0; index < 16; index++) {
      expect(model.stars[index].alpha, isNot(before[index]));
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('switching reduced motion on mid-flight lands the comets', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _layer(stage: VoiceLevelStage.breathing, random: math.Random(5)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final CometsModel model = _layerModel(tester);
    final Comet first = model.comets[0];
    expect(first.born, 0);
    expect(first.ease, closeTo(1 - math.pow(1 - 0.3 / 1.1, 3), 1e-9));
    expect(first.ease, lessThan(1));

    await tester.pumpWidget(
      _layer(
        stage: VoiceLevelStage.breathing,
        random: math.Random(5),
        still: true,
      ),
    );
    expect(first.ease, 1);
    expect(first.radiusFactor, 1);
    final List<double> alphas = <double>[
      for (final CometStar star in model.stars) star.alpha,
    ];
    final List<double> twinkles = <double>[
      for (final CometStar star in model.stars) star.twinkle,
    ];

    await tester.pump(const Duration(milliseconds: 200));
    for (int index = 0; index < 16; index++) {
      expect(model.stars[index].alpha, alphas[index]);
      expect(model.stars[index].twinkle, twinkles[index]);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
