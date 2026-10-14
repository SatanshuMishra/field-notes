import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'voice_level_smoother.dart';

enum VoiceLevelStage { breathing, recording, paused }

const int _cometCount = 4;
const int _starCount = 16;

const double _ringInset = 12;
const double _edgeMargin = 6;
const double _hiddenMargin = 1;

const double _orbitFloor = 0.45;
const double _orbitStep = 0.12;
const double _eccentricityFloor = 0.38;
const double _eccentricityStep = 0.06;
const double _tiltFloor = 1;
const double _tiltStep = 0.12;
const double _turnStep = 1.6;
const double _turnOffset = 1.2;
const double _startAngleStep = 1.7;

const double _speedShare = 0.5;
const double _speedRest = 0.35;
const double _speedLevel = 2.4;
const double _speedBrightness = 1.5;
const double _speedPull = 1.6;

const double _brightnessFade = 1.6;
const double _trailSpanFloor = 0.9;
const double _trailSpanBrightness = 0.8;
const double _trailFadePower = 1.5;
const double _farSideShare = 0.45;
const double _trailWidthFloor = 0.6;
const double _trailWidthBrightness = 2.2;
const double _trailThinning = 0.7;
const double _hotBrightness = 0.25;
const double _coolTrailShare = 0.8;
const double _headFloor = 1.6;
const double _headBrightness = 1.8;

const double _flyInSeconds = 1.1;
const double _flyInStretch = 1.4;
const double _flyInPower = 3;

const int _breathMarks = 3;
const double _markSeconds = 1;
const double _markTolerance = 1e-9;

const double _glowAlphaFloor = 0.14;
const double _glowAlphaLevel = 0.28;
const double _glowAlphaBreath = 0.05;
const double _glowBreathRate = 0.63;
const double _glowReachFloor = 0.5;
const double _glowReachLevel = 0.5;

const double _starInset = 12;
const double _starReach = 1.1;
const double _starArmFloor = 0.6;
const double _starArmSpread = 1.4;
const double _starArmBase = 1.6;
const double _starArmFlash = 3.5;
const double _starAlphaFloor = 0.18;
const double _starTwinkleDepth = 0.1;
const double _starTwinkleRate = 1.3;
const double _starFlashAlpha = 0.8;
const double _starFade = 2.2;
const double _starStroke = 1;
const double _loudOnset = 0.45;

const Color _glowRose = Color(0xFFB8566A);
const Color _hotTrailInk = Color(0xFFE58D9C);
const Color _coolTrailInk = Color(0xFFF3E6D1);
const Color _headInk = Color(0xFFF3E6D1);
const Color _starInk = Color(0xFFF3E6D1);

@immutable
class CometPoint {
  const CometPoint({
    required this.offset,
    required this.depth,
    required this.hidden,
  });

  final Offset offset;
  final double depth;
  final bool hidden;
}

CometPoint projectCometPoint({
  required Offset centre,
  required double orbRadius,
  required double radius,
  required double angle,
  required double tilt,
  required double turn,
}) {
  final double x = radius * math.cos(angle);
  final double y = radius * math.sin(angle) * math.cos(tilt);
  final double depth = radius * math.sin(angle) * math.sin(tilt);
  final Offset turned = Offset(
    x * math.cos(turn) - y * math.sin(turn),
    x * math.sin(turn) + y * math.cos(turn),
  );
  return CometPoint(
    offset: centre + turned,
    depth: depth,
    hidden: depth < 0 && turned.distance < orbRadius + _hiddenMargin,
  );
}

@immutable
class CometTrailPoint {
  const CometTrailPoint({required this.point, required this.time});

  final CometPoint point;
  final double time;
}

@immutable
class CometTrailSegment {
  const CometTrailSegment({
    required this.start,
    required this.end,
    required this.color,
    required this.width,
  });

  final Offset start;
  final Offset end;
  final Color color;
  final double width;
}

@immutable
class CometHead {
  const CometHead({
    required this.centre,
    required this.radius,
    required this.color,
  });

  final Offset centre;
  final double radius;
  final Color color;
}

@immutable
class CometsGlow {
  const CometsGlow({
    required this.inner,
    required this.outer,
    required this.color,
  });

  final double inner;
  final double outer;
  final Color color;
}

double cometTrailSpan(double brightness) =>
    _trailSpanFloor + _trailSpanBrightness * brightness;

List<CometTrailSegment> cometTrailSegments({
  required List<CometTrailPoint> trail,
  required double now,
  required double brightness,
  required double level,
  required double ease,
}) {
  final double span = cometTrailSpan(brightness);
  final bool hot = brightness > _hotBrightness;
  final double widest =
      _trailWidthFloor + _trailWidthBrightness * brightness + level;
  return <CometTrailSegment>[
    for (int index = 1; index < trail.length; index++)
      if (!trail[index - 1].point.hidden && !trail[index].point.hidden)
        _trailSegment(
          older: trail[index - 1].point,
          newer: trail[index],
          age: ((now - trail[index].time) / span).clamp(0.0, 1.0),
          hot: hot,
          widest: widest,
          ease: ease,
        ),
  ];
}

CometTrailSegment _trailSegment({
  required CometPoint older,
  required CometTrailPoint newer,
  required double age,
  required bool hot,
  required double widest,
  required double ease,
}) {
  final double alpha =
      math.pow(1 - age, _trailFadePower).toDouble() *
      (newer.point.depth < 0 ? _farSideShare : 1) *
      ease;
  return CometTrailSegment(
    start: older.offset,
    end: newer.point.offset,
    color: hot
        ? _hotTrailInk.withValues(alpha: alpha)
        : _coolTrailInk.withValues(alpha: _coolTrailShare * alpha),
    width: widest * (1 - _trailThinning * age),
  );
}

class Comet {
  Comet._(this._model, this.index)
    : eccentricity = _eccentricityFloor + _eccentricityStep * index,
      tilt = _tiltFloor + _tiltStep * index,
      turn = _turnStep * index - _turnOffset,
      _angle = _startAngleStep * index;

  final CometsModel _model;
  final int index;
  final double eccentricity;
  final double tilt;
  final double turn;
  double _angle;
  double _brightness = 0;
  double? _born;
  final List<CometTrailPoint> _trail = <CometTrailPoint>[];

  double get semiMajor =>
      _model.innerRadius + _model.reach * (_orbitFloor + _orbitStep * index);

  double get angle => _angle;

  double get brightness => _brightness;

  double? get born => _born;

  bool get isBorn => _born != null;

  double get ease {
    final double? born = _born;
    if (born == null) {
      return 0;
    }
    if (_model.still) {
      return 1;
    }
    final double share = ((_model.time - born) / _flyInSeconds).clamp(0.0, 1.0);
    return 1 - math.pow(1 - share, _flyInPower).toDouble();
  }

  double get radiusFactor => 1 + _flyInStretch * (1 - ease);

  double get radius =>
      semiMajor *
      (1 - eccentricity * eccentricity) /
      (1 + eccentricity * math.cos(_angle)) *
      radiusFactor;

  CometPoint get point => projectCometPoint(
    centre: _model.centre,
    orbRadius: _model.orbRadius,
    radius: radius,
    angle: _angle,
    tilt: tilt,
    turn: turn,
  );

  double get trailSpan => cometTrailSpan(_brightness);

  List<CometTrailPoint> get trail => List<CometTrailPoint>.unmodifiable(_trail);

  List<CometTrailSegment> get segments => isBorn
      ? cometTrailSegments(
          trail: _trail,
          now: _model.time,
          brightness: _brightness,
          level: _model.level,
          ease: ease,
        )
      : const <CometTrailSegment>[];

  CometHead? get head {
    if (!isBorn) {
      return null;
    }
    final CometPoint point = this.point;
    if (point.hidden) {
      return null;
    }
    return CometHead(
      centre: point.offset,
      radius: _headFloor + _headBrightness * _brightness,
      color: _headInk,
    );
  }

  void _brighten(double intensity) {
    _brightness = math.min(1, _brightness + intensity);
  }

  void _advance(double dt, double level) {
    _brightness *= math.exp(-_brightnessFade * dt);
    final double pull = _model.still ? 0 : _brightness;
    final double speed =
        _speedShare *
        (_speedRest + _speedLevel * level + _speedBrightness * pull) *
        math.pow(semiMajor / radius, _speedPull).toDouble();
    _angle += speed * dt;
    final double now = _model.time;
    _trail.add(CometTrailPoint(point: point, time: now));
    final double span = trailSpan;
    int stale = 0;
    while (stale < _trail.length && now - _trail[stale].time > span) {
      stale++;
    }
    _trail.removeRange(0, stale);
  }
}

class CometStar {
  CometStar._(
    this._model, {
    required this._angle,
    required this._share,
    required this.size,
    required this._twinkle,
  });

  final CometsModel _model;
  final double _angle;
  final double _share;
  final double size;
  double _twinkle;
  double _flash = 0;

  double get distance =>
      _model.innerRadius +
      _starInset +
      _share * math.max(0, _starReach * _model.reach - _starInset);

  Offset get centre =>
      _model.centre +
      Offset(math.cos(_angle) * distance, math.sin(_angle) * distance);

  double get twinkle => _twinkle;

  double get flash => _flash;

  double get arm => size * (_starArmBase + _starArmFlash * _flash);

  double get alpha =>
      (_starAlphaFloor +
              _starTwinkleDepth * math.sin(_starTwinkleRate * _twinkle) +
              _starFlashAlpha * _flash)
          .clamp(0.0, 1.0);

  void _advance(double dt) {
    if (_model.still) {
      _flash = 0;
      return;
    }
    _flash *= math.exp(-_starFade * dt);
    _twinkle += dt;
  }
}

class CometsModel {
  CometsModel({
    required this._size,
    required this._orbRadius,
    required this._random,
    required this._stage,
    VoiceLevelSmoother? smoother,
    this._still = false,
  }) : _smoother = smoother ?? VoiceLevelSmoother() {
    _comets = List<Comet>.unmodifiable(<Comet>[
      for (int index = 0; index < _cometCount; index++) Comet._(this, index),
    ]);
    _stars = List<CometStar>.unmodifiable(<CometStar>[
      for (int index = 0; index < _starCount; index++) _drawStar(),
    ]);
  }

  final math.Random _random;
  final VoiceLevelSmoother _smoother;
  late final List<Comet> _comets;
  late final List<CometStar> _stars;
  Size _size;
  double _orbRadius;
  VoiceLevelStage _stage;
  bool _still;
  double _time = 0;
  double? _firstFrame;
  VoiceLevelStage? _firstStage;
  double? _recordingFrom;

  CometStar _drawStar() {
    final double angle = _random.nextDouble() * 2 * math.pi;
    final double share = _random.nextDouble();
    final double size = _starArmFloor + _random.nextDouble() * _starArmSpread;
    final double twinkle = _random.nextDouble() * 2 * math.pi;
    return CometStar._(
      this,
      angle: angle,
      share: share,
      size: size,
      twinkle: twinkle,
    );
  }

  Size get size => _size;

  double get orbRadius => _orbRadius;

  Offset get centre => _size.center(Offset.zero);

  double get innerRadius => _orbRadius + _ringInset;

  double get reach =>
      math.max(0, _size.shortestSide / 2 - innerRadius - _edgeMargin);

  double get time => _time;

  double get level => _smoother.level;

  bool get still => _still;

  set still(bool value) {
    if (value == _still) {
      return;
    }
    _still = value;
    if (value) {
      for (final CometStar star in _stars) {
        star._flash = 0;
      }
    }
  }

  VoiceLevelStage get stage => _stage;

  set stage(VoiceLevelStage value) {
    if (value == _stage) {
      return;
    }
    _stage = value;
    if (value != VoiceLevelStage.recording) {
      _smoother.hush();
    }
    _noteRecording();
    _bear();
  }

  List<Comet> get comets => _comets;

  List<CometStar> get stars => _stars;

  CometsGlow get glow {
    final double level = this.level;
    final double breath = 0.5 + 0.5 * math.sin(_glowBreathRate * _time);
    return CometsGlow(
      inner: _orbRadius,
      outer: innerRadius + reach * (_glowReachFloor + _glowReachLevel * level),
      color: _glowRose.withValues(
        alpha:
            (_glowAlphaFloor +
                    _glowAlphaLevel * level +
                    _glowAlphaBreath * breath)
                .clamp(0.0, 1.0),
      ),
    );
  }

  Duration get _clock =>
      Duration(microseconds: (_time * Duration.microsecondsPerSecond).round());

  void resize(Size size, double orbRadius) {
    if (size == _size && orbRadius == _orbRadius) {
      return;
    }
    _size = size;
    _orbRadius = orbRadius;
    for (final Comet comet in _comets) {
      comet._trail.clear();
    }
  }

  void hear(double level) {
    if (_stage != VoiceLevelStage.recording) {
      return;
    }
    final VoiceLevelOnset? onset = _smoother.hear(level, _clock);
    if (onset != null) {
      this.onset(onset.intensity);
    }
  }

  void onset(double intensity) {
    if (_stage != VoiceLevelStage.recording ||
        !intensity.isFinite ||
        intensity <= 0) {
      return;
    }
    _comets[_random.nextInt(_comets.length)]._brighten(intensity);
    if (intensity > _loudOnset && !_still) {
      _stars[_random.nextInt(_stars.length)]._flash = 1;
    }
  }

  void advance(double dtSeconds) {
    final double dt = dtSeconds.isFinite && dtSeconds > 0 ? dtSeconds : 0;
    if (_firstFrame == null) {
      _firstFrame = _time;
      _firstStage = _stage;
    }
    _time += dt;
    _noteRecording();
    _smoother.advance(dt);
    _bear();
    for (final CometStar star in _stars) {
      star._advance(dt);
    }
    final double level = _still ? 0 : this.level;
    for (final Comet comet in _comets) {
      if (comet.isBorn) {
        comet._advance(dt, level);
      }
    }
  }

  void _noteRecording() {
    if (_stage == VoiceLevelStage.recording &&
        _firstFrame != null &&
        _recordingFrom == null) {
      _recordingFrom = _time;
    }
  }

  void _bear() {
    final double? first = _firstFrame;
    if (first == null) {
      return;
    }
    final double? recordingFrom = _recordingFrom;
    for (final Comet comet in _comets) {
      if (comet._born != null) {
        continue;
      }
      if (_firstStage != VoiceLevelStage.breathing) {
        comet._born = first;
      } else if (comet.index < _breathMarks) {
        final double mark = first + comet.index * _markSeconds;
        if (_time >= mark - _markTolerance) {
          comet._born = mark;
        }
      } else if (recordingFrom != null) {
        comet._born = recordingFrom;
      }
    }
  }
}

class CometsPainter extends CustomPainter {
  CometsPainter({required this.model, super.repaint});

  final CometsModel model;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    canvas.clipRect(Offset.zero & size);
    _paintGlow(canvas);
    _paintStars(canvas);
    _paintTrails(canvas);
    _paintHeads(canvas);
  }

  void _paintGlow(Canvas canvas) {
    final CometsGlow glow = model.glow;
    if (glow.outer <= glow.inner) {
      return;
    }
    final Offset centre = model.centre;
    final Path ring = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(Rect.fromCircle(center: centre, radius: glow.outer))
      ..addOval(Rect.fromCircle(center: centre, radius: glow.inner));
    canvas.drawPath(
      ring,
      Paint()
        ..shader = ui.Gradient.radial(
          centre,
          glow.outer,
          <Color>[glow.color, glow.color.withValues(alpha: 0)],
          <double>[glow.inner / glow.outer, 1],
        ),
    );
  }

  void _paintStars(Canvas canvas) {
    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = _starStroke;
    for (final CometStar star in model.stars) {
      final Offset centre = star.centre;
      final double arm = star.arm;
      stroke.color = _starInk.withValues(alpha: star.alpha);
      canvas
        ..drawLine(centre - Offset(arm, 0), centre + Offset(arm, 0), stroke)
        ..drawLine(centre - Offset(0, arm), centre + Offset(0, arm), stroke);
    }
  }

  void _paintTrails(Canvas canvas) {
    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final Comet comet in model.comets) {
      for (final CometTrailSegment segment in comet.segments) {
        stroke
          ..color = segment.color
          ..strokeWidth = segment.width;
        canvas.drawLine(segment.start, segment.end, stroke);
      }
    }
  }

  void _paintHeads(Canvas canvas) {
    final Paint fill = Paint();
    for (final Comet comet in model.comets) {
      final CometHead? head = comet.head;
      if (head != null) {
        fill.color = head.color;
        canvas.drawCircle(head.centre, head.radius, fill);
      }
    }
  }

  @override
  bool shouldRepaint(CometsPainter oldDelegate) => oldDelegate.model != model;
}

class VoiceLevelField extends StatefulWidget {
  const VoiceLevelField({
    super.key,
    required this.levels,
    required this.stage,
    required this.orbRadius,
    this.random,
  });

  final Stream<double> levels;
  final VoiceLevelStage stage;
  final double orbRadius;
  final math.Random? random;

  @override
  State<VoiceLevelField> createState() => VoiceLevelFieldState();
}

class VoiceLevelFieldState extends State<VoiceLevelField>
    with SingleTickerProviderStateMixin {
  late final math.Random _random = widget.random ?? math.Random();
  late final Ticker _ticker = createTicker(_tick);
  final ValueNotifier<int> _frames = ValueNotifier<int>(0);
  late StreamSubscription<double> _subscription;
  CometsModel? _model;
  Duration _lastElapsed = Duration.zero;
  bool _still = false;

  CometsModel? get model => _model;

  @override
  void initState() {
    super.initState();
    _subscription = widget.levels.listen(_hear);
  }

  void _hear(double level) {
    _model?.hear(level);
  }

  void _tick(Duration elapsed) {
    final double dtSeconds =
        (elapsed - _lastElapsed).inMicroseconds /
        Duration.microsecondsPerSecond;
    _lastElapsed = elapsed;
    final CometsModel? model = _model;
    if (model == null) {
      return;
    }
    model.advance(dtSeconds);
    _frames.value++;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
    _model?.still = _still;
    if (!_ticker.isActive) {
      _lastElapsed = Duration.zero;
      _ticker.start();
    }
  }

  @override
  void didUpdateWidget(VoiceLevelField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.levels != oldWidget.levels) {
      _subscription.cancel();
      _subscription = widget.levels.listen(_hear);
    }
    _model?.stage = widget.stage;
  }

  @override
  void dispose() {
    _subscription.cancel();
    _ticker.dispose();
    _frames.dispose();
    super.dispose();
  }

  CometsModel _modelFor(Size size) {
    final CometsModel? model = _model;
    if (model != null) {
      model.resize(size, widget.orbRadius);
      return model;
    }
    return _model = CometsModel(
      size: size,
      orbRadius: widget.orbRadius,
      random: _random,
      stage: widget.stage,
      still: _still,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final CometsModel model = _modelFor(constraints.biggest);
        return IgnorePointer(
          child: ExcludeSemantics(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: CometsPainter(model: model, repaint: _frames),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        );
      },
    );
  }
}
