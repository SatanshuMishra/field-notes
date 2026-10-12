import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/features/capture/immersive/immersive.dart';

const double _step60 = 1 / 60;
const double _step120 = 1 / 120;
const int _parkMillerModulus = 2147483647;

const double _orbRadius = 62;
const int _seed = 3;
const double _fieldSize = 370;
const double _inner = _orbRadius + 12;
const double _reach = _fieldSize / 2 - _inner - 6;
const double _ringRest = _inner - 5;
const Offset _centre = Offset(_fieldSize / 2, _fieldSize / 2);
const Duration _frame = Duration(milliseconds: 16);

const Color _hotTickInk = Color(0xFFE58D9C);
const Color _coolTickInk = Color(0xFFE7BEAA);
const Color _ringInk = Color(0xFFE7A087);

final Finder _field = find.byType(VoiceLevelField);

class _FixedRandom implements math.Random {
  const _FixedRandom(this.value);

  final double value;

  @override
  double nextDouble() => value;

  @override
  int nextInt(int max) => 0;

  @override
  bool nextBool() => false;
}

VoiceLevelFieldModel _calmModel(int seed) =>
    VoiceLevelFieldModel(seed: seed, spikes: const _FixedRandom(1));

List<double> _parkMillerDraws(int seed, int count) {
  final List<double> draws = <double>[];
  int state = seed;
  for (int index = 0; index < count; index++) {
    state = state * 16807 % _parkMillerModulus;
    draws.add(state / _parkMillerModulus);
  }
  return draws;
}

double _drive(
  VoiceLevelFieldModel model, {
  required double target,
  required double from,
  required int frames,
  required double step,
}) {
  for (int frame = 1; frame <= frames; frame++) {
    model.advance(
      target: target,
      seconds: from + frame * step,
      dtSeconds: step,
    );
  }
  return from + frames * step;
}

List<double> _phases(VoiceLevelFieldModel model) => <double>[
  for (int index = 0; index < VoiceLevelFieldModel.tickCount; index++)
    model.phase(index),
];

List<double> _speeds(VoiceLevelFieldModel model) => <double>[
  for (int index = 0; index < VoiceLevelFieldModel.tickCount; index++)
    model.speed(index),
];

List<double> _amplitudes(VoiceLevelFieldModel model) => <double>[
  for (int index = 0; index < VoiceLevelFieldModel.tickCount; index++)
    model.amplitude(index),
];

void _useWindow(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _stage({
  required Stream<double> levels,
  required bool active,
  required VoidCallback onTap,
  bool shown = true,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: fieldNotesTheme(platform: TargetPlatform.macOS),
    home: ColoredBox(
      color: recorderStageColor,
      child: Center(
        child: SizedBox.square(
          dimension: _fieldSize,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                excludeFromSemantics: true,
                onTap: onTap,
                child: const SizedBox.expand(),
              ),
              if (shown)
                VoiceLevelField(
                  levels: levels,
                  active: active,
                  orbRadius: _orbRadius,
                  seed: _seed,
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> _pumpFrames(WidgetTester tester, int count) async {
  for (int frame = 0; frame < count; frame++) {
    await tester.pump(_frame);
  }
}

int _paints(WidgetTester tester) {
  final RenderRepaintBoundary boundary = tester
      .renderObject<RenderRepaintBoundary>(
        find.descendant(of: _field, matching: find.byType(RepaintBoundary)),
      );
  return boundary.debugSymmetricPaintCount + boundary.debugAsymmetricPaintCount;
}

List<Invocation> _drawn(WidgetTester tester) {
  final RenderCustomPaint render = tester.renderObject<RenderCustomPaint>(
    find.descendant(of: _field, matching: find.byType(CustomPaint)),
  );
  final TestRecordingCanvas canvas = TestRecordingCanvas();
  render.painter!.paint(canvas, render.size);
  return <Invocation>[
    for (final RecordedInvocation call in canvas.invocations) call.invocation,
  ];
}

List<Invocation> _calls(List<Invocation> drawn, Symbol name) => <Invocation>[
  for (final Invocation call in drawn)
    if (call.memberName == name) call,
];

double _ringRadius(WidgetTester tester) =>
    _calls(_drawn(tester), #drawCircle).last.positionalArguments[1] as double;

List<Offset> _tickEnds(WidgetTester tester) => <Offset>[
  for (final Invocation line in _calls(_drawn(tester), #drawLine))
    line.positionalArguments[1] as Offset,
];

int _nodesUnder(SemanticsNode node) {
  final List<SemanticsNode> children = <SemanticsNode>[];
  node.visitChildren((SemanticsNode child) {
    children.add(child);
    return true;
  });
  return children.fold<int>(
    1,
    (int count, SemanticsNode child) => count + _nodesUnder(child),
  );
}

int _semanticsNodes(WidgetTester tester) => <int>[
  for (final RenderView view in tester.binding.renderViews)
    if (view.owner?.semanticsOwner?.rootSemanticsNode
        case final SemanticsNode root)
      _nodesUnder(root),
].fold<int>(0, (int total, int count) => total + count);

Offset _polar(double angle, double radius) =>
    _centre + Offset(math.cos(angle) * radius, math.sin(angle) * radius);

void _expectStill(WidgetTester tester, double level) {
  final VoiceLevelFieldModel seeded = VoiceLevelFieldModel(seed: _seed);
  final List<Invocation> drawn = _drawn(tester);
  final List<Invocation> lines = _calls(drawn, #drawLine);
  expect(lines, hasLength(VoiceLevelFieldModel.tickCount));
  for (int index = 0; index < lines.length; index++) {
    final double length = 0.05 + level * seeded.amplitude(index);
    final double angle =
        index / VoiceLevelFieldModel.tickCount * 2 * math.pi - math.pi / 2;
    final double start = _inner + math.sin(index.toDouble()) * 1.2;
    final double end = start + 3 + length * _reach;
    final double tilt = (seeded.phase(index) - math.pi) * 0.02;
    final bool hot = length > 0.42;
    final Paint paint = lines[index].positionalArguments[2] as Paint;
    expect(
      ((lines[index].positionalArguments[0] as Offset) - _polar(angle, start))
          .distance,
      lessThan(1e-9),
      reason: 'tick $index start at level $level',
    );
    expect(
      ((lines[index].positionalArguments[1] as Offset) -
              _polar(angle + tilt, end))
          .distance,
      lessThan(1e-9),
      reason: 'tick $index end at level $level',
    );
    expect(
      paint.strokeWidth,
      closeTo(hot ? 2.6 : 1.8, 1e-6),
      reason: 'tick $index width',
    );
    expect(paint.strokeCap, StrokeCap.round, reason: 'tick $index cap');
    expect(
      paint.color.toARGB32(),
      (hot
              ? _hotTickInk.withValues(
                  alpha: (0.55 + length * 0.45).clamp(0.0, 1.0),
                )
              : _coolTickInk.withValues(
                  alpha: (0.22 + length * 0.6).clamp(0.0, 1.0),
                ))
          .toARGB32(),
      reason: 'tick $index colour',
    );
  }
  final List<Invocation> circles = _calls(drawn, #drawCircle);
  expect(circles, hasLength(2));
  expect(circles.first.positionalArguments[0], _centre);
  expect(
    circles.first.positionalArguments[1] as double,
    closeTo(_inner + _reach * 1.1, 1e-9),
  );
  expect((circles.first.positionalArguments[2] as Paint).shader, isNotNull);
  final Invocation ring = circles.last;
  final Paint ringPaint = ring.positionalArguments[2] as Paint;
  expect(ring.positionalArguments[0], _centre);
  expect(
    ring.positionalArguments[1] as double,
    closeTo(_ringRest + level * 3, 1e-9),
    reason: 'ring at level $level',
  );
  expect(ringPaint.style, PaintingStyle.stroke);
  expect(ringPaint.strokeWidth, closeTo(1, 1e-6));
  expect(
    ringPaint.color.toARGB32(),
    _ringInk.withValues(alpha: 0.16 + level * 0.25).toARGB32(),
  );
}

void main() {
  test('the level field smooths toward the voice and rests when inactive', () {
    const int count = VoiceLevelFieldModel.tickCount;

    final VoiceLevelFieldModel rising = _calmModel(_seed);
    expect(rising.level, 0);
    expect(rising.ticks, hasLength(count));
    expect(rising.ticks, everyElement(0));
    expect(() => rising.ticks[0] = 1, throwsUnsupportedError);
    rising.advance(target: 1, seconds: _step60, dtSeconds: _step60);
    expect(
      rising.level,
      closeTo(0.32, 1e-12),
      reason: 'rising closes 32 % of the gap in 1/60 s',
    );
    rising.advance(target: 0, seconds: 2 * _step60, dtSeconds: _step60);
    expect(
      rising.level,
      closeTo(0.32 * (1 - 0.085), 1e-12),
      reason: 'falling closes 8.5 % of the gap in 1/60 s',
    );

    final VoiceLevelFieldModel at60 = _calmModel(_seed);
    final VoiceLevelFieldModel at120 = _calmModel(_seed);
    double clock = 0;
    for (final double target in <double>[0.8, 0.2, 1, 0]) {
      for (int frame = 0; frame < 30; frame++) {
        _drive(at60, target: target, from: clock, frames: 1, step: _step60);
        clock = _drive(
          at120,
          target: target,
          from: clock,
          frames: 2,
          step: _step120,
        );
        expect(
          at120.level,
          closeTo(at60.level, 1e-6),
          reason: '120 Hz matches 60 Hz toward $target at frame $frame',
        );
      }
    }

    final VoiceLevelFieldModel resting = _calmModel(_seed);
    final double loudUntil = _drive(
      resting,
      target: 1,
      from: 0,
      frames: 120,
      step: _step60,
    );
    expect(resting.level, greaterThan(0.99));
    _drive(resting, target: 0, from: loudUntil, frames: 120, step: _step60);
    expect(
      resting.level,
      lessThan(0.01),
      reason: 'an inactive field rests within 2 s',
    );
    expect(resting.ticks, everyElement(closeTo(0.05, 0.01)));

    final List<double> draws = _parkMillerDraws(_seed, 3 * count);
    final VoiceLevelFieldModel first = _calmModel(3);
    final VoiceLevelFieldModel again = _calmModel(3);
    final VoiceLevelFieldModel other = _calmModel(7);
    for (int index = 0; index < count; index++) {
      expect(
        first.phase(index),
        closeTo(draws[index] * 2 * math.pi, 1e-12),
        reason: 'phase $index',
      );
      expect(
        first.speed(index),
        closeTo(0.6 + draws[count + index] * 1.8, 1e-12),
        reason: 'speed $index',
      );
      expect(
        first.amplitude(index),
        closeTo(0.45 + draws[2 * count + index] * 0.55, 1e-12),
        reason: 'amplitude $index',
      );
    }
    expect(_phases(again), _phases(first));
    expect(_speeds(again), _speeds(first));
    expect(_amplitudes(again), _amplitudes(first));
    expect(_phases(other), isNot(equals(_phases(first))));
    expect(_speeds(other), isNot(equals(_speeds(first))));
    expect(_amplitudes(other), isNot(equals(_amplitudes(first))));
    expect(_phases(_calmModel(0)), _phases(_calmModel(1)));
    expect(_amplitudes(_calmModel(0)), _amplitudes(_calmModel(1)));

    final VoiceLevelFieldModel spiking = VoiceLevelFieldModel(
      seed: _seed,
      spikes: const _FixedRandom(0),
    );
    final VoiceLevelFieldModel steady = _calmModel(_seed);
    for (int frame = 1; frame <= 600; frame++) {
      spiking.advance(target: 1, seconds: frame * _step60, dtSeconds: _step60);
      steady.advance(target: 1, seconds: frame * _step60, dtSeconds: _step60);
      expect(
        spiking.ticks,
        everyElement(inInclusiveRange(0.0, 1.55)),
        reason: 'spiking ticks at frame $frame',
      );
      expect(
        steady.ticks,
        everyElement(inInclusiveRange(0.0, 1.05)),
        reason: 'steady ticks at frame $frame',
      );
    }
    for (int index = 0; index < count; index++) {
      expect(
        spiking.ticks[index] - steady.ticks[index],
        closeTo(0.5, 1e-3),
        reason: 'tick $index spikes by half the level',
      );
    }
  });

  testWidgets(
    'the level field paints from its stream and stays out of semantics',
    (WidgetTester tester) async {
      _useWindow(tester);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final SemanticsHandle semantics = tester.ensureSemantics();
      final StreamController<double> voice =
          StreamController<double>.broadcast();
      int taps = 0;
      void tapped() => taps++;

      await tester.pumpWidget(
        _stage(levels: voice.stream, active: true, onTap: tapped, shown: false),
      );
      final int bareNodes = _semanticsNodes(tester);
      await tester.pumpWidget(
        _stage(levels: voice.stream, active: true, onTap: tapped),
      );
      await tester.pump(_frame);

      expect(voice.hasListener, isTrue);
      expect(tester.getSize(_field), const Size(_fieldSize, _fieldSize));
      expect(_semanticsNodes(tester), bareNodes);
      expect(
        find.descendant(
          of: _field,
          matching: find.byWidgetPredicate(
            (Widget widget) => widget is ExcludeSemantics && widget.excluding,
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _field,
          matching: find.byWidgetPredicate(
            (Widget widget) => widget is IgnorePointer && widget.ignoring,
          ),
        ),
        findsOneWidget,
      );
      await tester.tapAt(tester.getCenter(_field));
      await tester.pump(_frame);
      expect(taps, 1, reason: 'a tap passes through the field');

      expect(
        tester.binding.hasScheduledFrame,
        isTrue,
        reason: 'the field animates while it is shown',
      );
      final int painted = _paints(tester);
      await _pumpFrames(tester, 30);
      expect(_paints(tester), greaterThanOrEqualTo(painted + 30));
      expect(
        _ringRadius(tester),
        closeTo(_ringRest, 1e-9),
        reason: 'silence draws the ring at rest',
      );

      voice.add(1);
      await _pumpFrames(tester, 60);
      expect(
        _ringRadius(tester),
        greaterThan(_ringRest + 2.9),
        reason: 'a loud voice grows the ring',
      );
      final List<Offset> settled = _tickEnds(tester);
      await tester.pump(_frame);
      expect(
        _tickEnds(tester),
        isNot(equals(settled)),
        reason: 'the ticks keep their own motion',
      );

      await tester.pumpWidget(
        _stage(levels: voice.stream, active: false, onTap: tapped),
      );
      await _pumpFrames(tester, 125);
      expect(
        _ringRadius(tester),
        lessThan(_ringRest + 0.03),
        reason: 'an inactive field rests',
      );
      expect(
        tester.binding.hasScheduledFrame,
        isTrue,
        reason: 'an inactive field still moves while it is shown',
      );

      final StreamController<double> next =
          StreamController<double>.broadcast();
      await tester.pumpWidget(
        _stage(levels: next.stream, active: true, onTap: tapped),
      );
      expect(voice.hasListener, isFalse);
      expect(next.hasListener, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
      expect(next.hasListener, isFalse);
      expect(
        tester.binding.hasScheduledFrame,
        isFalse,
        reason: 'no ticker is left once the field is removed',
      );

      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      final StreamController<double> still =
          StreamController<double>.broadcast();
      await tester.pumpWidget(
        _stage(levels: still.stream, active: true, onTap: tapped),
      );
      await tester.pump();
      expect(
        tester.binding.hasScheduledFrame,
        isFalse,
        reason: 'no ticker runs under reduced motion',
      );
      _expectStill(tester, 0);
      final int stillPaints = _paints(tester);

      still.add(0.6);
      await tester.pump();
      expect(
        tester.binding.hasScheduledFrame,
        isTrue,
        reason: 'an arriving level repaints at once',
      );
      await tester.pump();
      expect(_paints(tester), stillPaints + 1);
      _expectStill(tester, 0.6);

      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(_paints(tester), stillPaints + 1);
      _expectStill(tester, 0.6);

      await tester.pumpWidget(
        _stage(levels: still.stream, active: false, onTap: tapped),
      );
      _expectStill(tester, 0);

      await tester.pumpWidget(const SizedBox.shrink());
      semantics.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );
}
