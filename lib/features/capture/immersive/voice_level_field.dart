import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'package:field_notes/design/tokens/tokens.dart';

const int _parkMillerMultiplier = 16807;
const int _parkMillerModulus = 2147483647;

const double _framesPerSecond = 60;
const double _riseRate = 0.32;
const double _fallRate = 0.085;
const double _tickFollowRate = 0.22;

const double _speedFloor = 0.6;
const double _speedSpread = 1.8;
const double _amplitudeFloor = 0.45;
const double _amplitudeSpread = 0.55;

const double _restLength = 0.05;
const double _wobbleSpeed = 2.2;
const double _wobbleDrift = 0.9;
const double _wobbleStagger = 0.37;
const double _wobbleFloor = 0.35;
const double _wobbleShare = 0.65;
const double _spikeChance = 0.04;
const double _spikeLength = 0.5;

const double _tickInset = 12;
const double _edgeMargin = 6;
const double _breathRate = 0.63;

const double _glowInner = 0.8;
const double _glowReachFloor = 0.55;
const double _glowReachLevel = 0.6;
const double _glowFill = 1.1;
const double _glowAlphaFloor = 0.30;
const double _glowAlphaLevel = 0.32;
const double _glowAlphaBreath = 0.06;

const double _tickJitterRate = 0.8;
const double _tickJitter = 1.2;
const double _tickBase = 3;
const double _tickTilt = 0.02;
const double _hotTickLength = 0.42;
const double _hotTickWidth = 2.6;
const double _coolTickWidth = 1.8;
const double _hotAlphaFloor = 0.55;
const double _hotAlphaLength = 0.45;
const double _coolAlphaFloor = 0.22;
const double _coolAlphaLength = 0.6;

const double _ringGap = 5;
const double _ringGrowth = 3;
const double _ringWidth = 1;
const double _ringAlphaFloor = 0.16;
const double _ringAlphaLevel = 0.25;

const Color _glowCoral = Palette.coral;
const Color _hotTickInk = Color(0xFFE58D9C);
const Color _coolTickInk = Color(0xFFE7BEAA);
const Color _ringInk = Color(0xFFE7A087);

class VoiceLevelFieldModel {
  VoiceLevelFieldModel({required int seed, math.Random? spikes})
    : this._(_parkMiller(seed, tickCount * 3), spikes ?? math.Random());

  VoiceLevelFieldModel._(List<double> draws, this._spikes)
    : _phases = _spread(draws, 0, 0, 2 * math.pi),
      _speeds = _spread(draws, 1, _speedFloor, _speedSpread),
      _amplitudes = _spread(draws, 2, _amplitudeFloor, _amplitudeSpread);

  static const int tickCount = 72;

  final math.Random _spikes;
  final List<double> _phases;
  final List<double> _speeds;
  final List<double> _amplitudes;
  final Float64List _ticks = Float64List(tickCount);
  late final List<double> _tickView = _ticks.asUnmodifiableView();
  double _level = 0;
  double _seconds = 0;

  double get level => _level;

  double get seconds => _seconds;

  List<double> get ticks => _tickView;

  double phase(int index) => _phases[index];

  double speed(int index) => _speeds[index];

  double amplitude(int index) => _amplitudes[index];

  static List<double> _parkMiller(int seed, int count) {
    final List<double> draws = <double>[];
    int state = seed == 0 ? 1 : seed;
    for (int index = 0; index < count; index++) {
      state = (state * _parkMillerMultiplier) % _parkMillerModulus;
      draws.add(state / _parkMillerModulus);
    }
    return draws;
  }

  static List<double> _spread(
    List<double> draws,
    int block,
    double floor,
    double range,
  ) => List<double>.unmodifiable(<double>[
    for (int index = 0; index < tickCount; index++)
      floor + draws[block * tickCount + index] * range,
  ]);

  static double _closed(double rate, double frames) =>
      1 - math.pow(1 - rate, frames).toDouble();

  void advance({
    required double target,
    required double seconds,
    required double dtSeconds,
  }) {
    final double frames = dtSeconds * _framesPerSecond;
    final double rate = target > _level ? _riseRate : _fallRate;
    _level += (target - _level) * _closed(rate, frames);
    _seconds = seconds;
    final double follow = _closed(_tickFollowRate, frames);
    for (int index = 0; index < tickCount; index++) {
      final double spike = _spikes.nextDouble() < _level * _spikeChance
          ? _level * _spikeLength
          : 0;
      final double aim = _aim(index, seconds) + spike;
      _ticks[index] += (aim - _ticks[index]) * follow;
    }
  }

  void settle(double target) {
    _level = target;
    _seconds = 0;
    for (int index = 0; index < tickCount; index++) {
      _ticks[index] = _restLength + target * _amplitudes[index];
    }
  }

  double _aim(int index, double seconds) {
    final double wobble =
        0.5 +
        0.5 *
            math.sin(seconds * _speeds[index] * _wobbleSpeed + _phases[index]) *
            math.sin(seconds * _wobbleDrift + index * _wobbleStagger);
    return _restLength +
        _level *
            _amplitudes[index] *
            (_wobbleFloor + _wobbleShare * wobble.abs());
  }
}

class VoiceLevelField extends StatefulWidget {
  const VoiceLevelField({
    super.key,
    required this.levels,
    required this.active,
    required this.orbRadius,
    required this.seed,
  });

  final Stream<double> levels;
  final bool active;
  final double orbRadius;
  final int seed;

  @override
  State<VoiceLevelField> createState() => _VoiceLevelFieldState();
}

class _VoiceLevelFieldState extends State<VoiceLevelField>
    with SingleTickerProviderStateMixin {
  late VoiceLevelFieldModel _model = VoiceLevelFieldModel(seed: widget.seed);
  late final Ticker _ticker = createTicker(_tick);
  final ValueNotifier<int> _frames = ValueNotifier<int>(0);
  late StreamSubscription<double> _subscription;
  double _heard = 0;
  Duration _lastElapsed = Duration.zero;
  bool _still = false;

  double get _target => widget.active ? _heard : 0;

  @override
  void initState() {
    super.initState();
    _subscription = widget.levels.listen(_hear);
  }

  void _hear(double level) {
    _heard = level;
    if (_still) {
      _settle();
    }
  }

  void _settle() {
    _model.settle(_target);
    _frames.value++;
  }

  void _tick(Duration elapsed) {
    final double dtSeconds =
        (elapsed - _lastElapsed).inMicroseconds /
        Duration.microsecondsPerSecond;
    _lastElapsed = elapsed;
    _model.advance(
      target: _target,
      seconds: _model.seconds + dtSeconds,
      dtSeconds: dtSeconds,
    );
    _frames.value++;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
    if (_still) {
      _ticker.stop();
      _settle();
    } else if (!_ticker.isActive) {
      _lastElapsed = Duration.zero;
      _ticker.start();
    }
  }

  @override
  void didUpdateWidget(VoiceLevelField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool listensElsewhere = widget.levels != oldWidget.levels;
    final bool reseeded = widget.seed != oldWidget.seed;
    if (listensElsewhere) {
      _subscription.cancel();
      _heard = 0;
      _subscription = widget.levels.listen(_hear);
    }
    if (reseeded) {
      _model = VoiceLevelFieldModel(seed: widget.seed);
    }
    if (_still &&
        (listensElsewhere || reseeded || widget.active != oldWidget.active)) {
      _settle();
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    _ticker.dispose();
    _frames.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _VoiceLevelFieldPainter(
              model: _model,
              orbRadius: widget.orbRadius,
              frames: _frames,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _VoiceLevelFieldPainter extends CustomPainter {
  _VoiceLevelFieldPainter({
    required this.model,
    required this.orbRadius,
    required this.frames,
  }) : super(repaint: frames);

  final VoiceLevelFieldModel model;
  final double orbRadius;
  final Listenable frames;

  static double _alpha(double value) => value.clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    canvas.clipRect(Offset.zero & size);
    final Offset centre = size.center(Offset.zero);
    final double inner = orbRadius + _tickInset;
    final double level = model.level;
    final double seconds = model.seconds;
    final double reach = math.max(
      0,
      size.shortestSide / 2 - inner - _edgeMargin,
    );
    final double breath = 0.5 + 0.5 * math.sin(seconds * _breathRate);
    _paintGlow(canvas, centre, inner, reach, level, breath);
    _paintTicks(canvas, centre, inner, reach, seconds);
    _paintRing(canvas, centre, inner, level);
  }

  void _paintGlow(
    Canvas canvas,
    Offset centre,
    double inner,
    double reach,
    double level,
    double breath,
  ) {
    final double from = orbRadius * _glowInner;
    final double to =
        inner + reach * (_glowReachFloor + level * _glowReachLevel);
    final double alpha = _alpha(
      _glowAlphaFloor + level * _glowAlphaLevel + breath * _glowAlphaBreath,
    );
    canvas.drawCircle(
      centre,
      inner + reach * _glowFill,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            _glowCoral.withValues(alpha: alpha),
            _glowCoral.withValues(alpha: 0),
          ],
          stops: <double>[from / to, 1],
        ).createShader(Rect.fromCircle(center: centre, radius: to)),
    );
  }

  void _paintTicks(
    Canvas canvas,
    Offset centre,
    double inner,
    double reach,
    double seconds,
  ) {
    final List<double> ticks = model.ticks;
    for (int index = 0; index < VoiceLevelFieldModel.tickCount; index++) {
      final double angle =
          index / VoiceLevelFieldModel.tickCount * 2 * math.pi - math.pi / 2;
      final double length = ticks[index];
      final double start =
          inner + math.sin(seconds * _tickJitterRate + index) * _tickJitter;
      final double end = start + _tickBase + length * reach;
      final double tilt = (model.phase(index) - math.pi) * _tickTilt;
      final bool hot = length > _hotTickLength;
      canvas.drawLine(
        centre + Offset(math.cos(angle) * start, math.sin(angle) * start),
        centre +
            Offset(math.cos(angle + tilt) * end, math.sin(angle + tilt) * end),
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = hot ? _hotTickWidth : _coolTickWidth
          ..color = hot
              ? _hotTickInk.withValues(
                  alpha: _alpha(_hotAlphaFloor + length * _hotAlphaLength),
                )
              : _coolTickInk.withValues(
                  alpha: _alpha(_coolAlphaFloor + length * _coolAlphaLength),
                ),
      );
    }
  }

  void _paintRing(Canvas canvas, Offset centre, double inner, double level) {
    canvas.drawCircle(
      centre,
      inner - _ringGap + level * _ringGrowth,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _ringWidth
        ..color = _ringInk.withValues(
          alpha: _alpha(_ringAlphaFloor + level * _ringAlphaLevel),
        ),
    );
  }

  @override
  bool shouldRepaint(_VoiceLevelFieldPainter oldDelegate) =>
      oldDelegate.model != model ||
      oldDelegate.orbRadius != orbRadius ||
      oldDelegate.frames != frames;
}
