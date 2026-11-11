import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/widgets.dart';

import 'package:field_notes/design/tokens/tokens.dart';

enum NightSkyKind { note, voice }

const Key nightSkyStillKey = ValueKey<String>('night-sky-still');
const Key nightSkyTwinkleKey = ValueKey<String>('night-sky-twinkle');
const Key nightSkyCometKey = ValueKey<String>('night-sky-comet');

const int nightSkyStarCount = 60;
const Duration nightSkyTwinkleStep = Duration(milliseconds: 83);
const Duration nightSkyCometQuiet = Duration(seconds: 30);
const Duration nightSkyCometFlight = Duration(milliseconds: 1100);

bool debugNightSkyStill = false;

const int _seedRange = 1 << 32;
const int _cometSeedOffset = 7919;
const int _sparkleSeedOffset = 104729;
const int _candidateCount = 600;
const int _sparkleCount = 3;
const int _sparkleCandidateCount = 60;

const double _edge = 0.01;
const double _thinnedKeep = 0.2;
const double _twinkleShare = 0.1;
const double _twinkleLow = 0.35;
const double _twinkleShortest = 4;
const double _twinkleSpread = 5;
const double _brightRoll = 0.92;
const double _midRoll = 0.65;
const double _brightDiameter = 2;
const double _midDiameter = 1.6;
const double _smallDiameter = 1.2;
const double _faintest = 0.42;
const double _softest = 0.9;

const double _sparkleMargin = 0.04;
const double _sparkleSmallest = 6;
const double _sparkleSpread = 4;
const double _sparkleStrength = 0.85;
const double _sparkleWaist = 0.07;

const double _noteColumnWidth = 720;
const double _noteTop = 0.14;
const double _noteBottom = 0.92;
const Offset _voiceCentre = Offset(0.5, 0.52);
const double _voiceReachX = 0.18;
const double _voiceReachY = 0.26;
const double _voiceReachFloor = 120;
const double _captionTop = 0.64;
const double _captionBottom = 0.74;
const double _captionReach = 0.16;
const double _captionReachFloor = 120;

const int _firstCometSpreadSeconds = 90;
const int _cometGapFloorSeconds = 60;
const int _cometGapSpreadSeconds = 120;
const double _cometLeftStart = 0.08;
const double _cometRightStart = 0.52;
const double _cometStartSpread = 0.4;
const double _cometTop = 0.04;
const double _cometTopSpread = 0.22;
const double _cometShallowest = 8 * math.pi / 180;
const double _cometSteepSpread = 18 * math.pi / 180;
const double _cometTravelFloor = 170;
const double _cometTravelSpread = 120;
const double _cometTail = 120;
const Cubic _cometCurve = Cubic(0.3, 0, 0.6, 1);
const double _cometRise = 0.12;
const double _cometFall = 0.75;
const double _cometWidth = 1.6;
const int _cometSegments = 14;
const double _streakBend = 0.55;
const double _streakBendShare = 0.15;
const double _streakHeadShare = 0.75;
const double _dashLength = 3;
const double _dashPitch = 7;
const double _dashShare = 0.55;
const double _cometHeadRadius = 2.5;
const double _cometHaloRadius = 3.5;
const double _cometHaloBlur = 3;
const double _cometHaloShare = 0.6;

bool get _debugStill {
  bool still = false;
  assert(() {
    still = debugNightSkyStill;
    return true;
  }());
  return still;
}

extension on NightSkyKind {
  bool thins(Offset share, Size size) {
    final double x = share.dx * size.width;
    final double y = share.dy * size.height;
    final double middle = size.width / 2;
    return switch (this) {
      NightSkyKind.note =>
        share.dy > _noteTop &&
            share.dy < _noteBottom &&
            (x - middle).abs() < math.min(size.width, _noteColumnWidth) / 2,
      NightSkyKind.voice => _nearOrb(x, y, size) || _nearCaption(x, y, size),
    };
  }

  bool _nearOrb(double x, double y, Size size) {
    final double reachX = math.max(size.width * _voiceReachX, _voiceReachFloor);
    final double reachY = math.max(
      size.height * _voiceReachY,
      _voiceReachFloor,
    );
    final double dx = (x - size.width * _voiceCentre.dx) / reachX;
    final double dy = (y - size.height * _voiceCentre.dy) / reachY;
    return dx * dx + dy * dy < 1;
  }

  bool _nearCaption(double x, double y, Size size) {
    final double reach = math.max(
      size.width * _captionReach,
      _captionReachFloor,
    );
    return y > size.height * _captionTop &&
        y < size.height * _captionBottom &&
        (x - size.width / 2).abs() < reach;
  }
}

@immutable
final class NightSkyTwinkle {
  const NightSkyTwinkle({required this.period, required this.phase});

  final double period;
  final double phase;

  double shareAt(double seconds) {
    final double wave =
        0.5 + 0.5 * math.cos(2 * math.pi * (seconds / period + phase));
    return _twinkleLow + (1 - _twinkleLow) * wave;
  }
}

@immutable
final class NightSkyStar {
  const NightSkyStar({
    required this.position,
    required this.diameter,
    required this.strength,
    this.twinkle,
  });

  final Offset position;
  final double diameter;
  final double strength;
  final NightSkyTwinkle? twinkle;
}

@immutable
final class NightSkySparkle {
  const NightSkySparkle({required this.position, required this.size});

  final Offset position;
  final double size;
}

typedef _Candidate = ({NightSkyStar star, double keep});

double _within(math.Random random) =>
    _edge + random.nextDouble() * (1 - 2 * _edge);

_Candidate _drawCandidate(math.Random random) {
  final Offset position = Offset(_within(random), _within(random));
  final double keep = random.nextDouble();
  final double size = random.nextDouble();
  final double strength = random.nextDouble();
  final double twinkles = random.nextDouble();
  final double period = random.nextDouble();
  final double phase = random.nextDouble();
  final bool bright = size > _brightRoll;
  return (
    star: NightSkyStar(
      position: position,
      diameter: bright
          ? _brightDiameter
          : size > _midRoll
          ? _midDiameter
          : _smallDiameter,
      strength: bright ? 1 : _faintest + (_softest - _faintest) * strength,
      twinkle: twinkles < _twinkleShare
          ? NightSkyTwinkle(
              period: _twinkleShortest + _twinkleSpread * period,
              phase: phase,
            )
          : null,
    ),
    keep: keep,
  );
}

NightSkySparkle _drawSparkle(math.Random random) {
  final double x =
      _sparkleMargin + random.nextDouble() * (1 - 2 * _sparkleMargin);
  final double y =
      _sparkleMargin + random.nextDouble() * (1 - 2 * _sparkleMargin);
  return NightSkySparkle(
    position: Offset(x, y),
    size: _sparkleSmallest + random.nextDouble() * _sparkleSpread,
  );
}

@immutable
final class NightSkyField {
  NightSkyField({
    required List<NightSkyStar> stars,
    required List<NightSkySparkle> sparkles,
  }) : stars = List<NightSkyStar>.unmodifiable(stars),
       sparkles = List<NightSkySparkle>.unmodifiable(sparkles),
       twinkling = List<NightSkyStar>.unmodifiable(
         stars.where((NightSkyStar star) => star.twinkle != null),
       );

  factory NightSkyField.scatter({
    required int seed,
    required NightSkyKind kind,
    required Size size,
  }) {
    final math.Random random = math.Random(seed);
    final List<_Candidate> candidates = List<_Candidate>.generate(
      _candidateCount,
      (int _) => _drawCandidate(random),
    );
    bool open(_Candidate candidate) =>
        !kind.thins(candidate.star.position, size) ||
        candidate.keep < _thinnedKeep;
    final math.Random sparkleRandom = math.Random(seed + _sparkleSeedOffset);
    final List<NightSkySparkle> sparkles = List<NightSkySparkle>.generate(
      _sparkleCandidateCount,
      (int _) => _drawSparkle(sparkleRandom),
    );
    bool clear(NightSkySparkle sparkle) => !kind.thins(sparkle.position, size);
    return NightSkyField(
      stars: <NightSkyStar>[
        for (final _Candidate candidate in candidates)
          if (open(candidate)) candidate.star,
        for (final _Candidate candidate in candidates)
          if (!open(candidate)) candidate.star,
      ].take(nightSkyStarCount).toList(),
      sparkles: <NightSkySparkle>[
        ...sparkles.where(clear),
        ...sparkles.where((NightSkySparkle sparkle) => !clear(sparkle)),
      ].take(_sparkleCount).toList(),
    );
  }

  final List<NightSkyStar> stars;
  final List<NightSkySparkle> sparkles;
  final List<NightSkyStar> twinkling;
}

@immutable
final class _Comet {
  const _Comet({
    required this.start,
    required this.heading,
    required this.travel,
  });

  factory _Comet.draw(math.Random random) {
    final bool fromLeft = random.nextBool();
    final double tilt =
        _cometShallowest + random.nextDouble() * _cometSteepSpread;
    final double angle = fromLeft ? tilt : math.pi - tilt;
    final double x =
        (fromLeft ? _cometLeftStart : _cometRightStart) +
        random.nextDouble() * _cometStartSpread;
    final double y = _cometTop + random.nextDouble() * _cometTopSpread;
    return _Comet(
      start: Offset(x, y),
      heading: Offset(math.cos(angle), math.sin(angle)),
      travel: _cometTravelFloor + random.nextDouble() * _cometTravelSpread,
    );
  }

  final Offset start;
  final Offset heading;
  final double travel;
}

class NightSky extends StatefulWidget {
  const NightSky({
    super.key,
    required this.kind,
    this.seed,
    this.holdComets = false,
  });

  final NightSkyKind kind;
  final int? seed;
  final bool holdComets;

  @override
  State<NightSky> createState() => _NightSkyState();
}

class _NightSkyState extends State<NightSky>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final int _seed = widget.seed ?? math.Random().nextInt(_seedRange);
  late final math.Random _cometRandom = math.Random(_seed + _cometSeedOffset);
  late final AnimationController _flight = AnimationController(
    vsync: this,
    duration: nightSkyCometFlight,
  )..addStatusListener(_onFlight);
  final ValueNotifier<double> _twinkleSeconds = ValueNotifier<double>(0);
  Timer? _twinkleTimer;
  Timer? _cometTimer;
  _Comet? _comet;
  bool _waitedFirst = false;
  bool _reduced = false;
  bool _ticking = true;
  bool _shown = true;
  NightSkyField? _field;
  Size? _fieldSize;

  bool get _moving => !_reduced && _ticking && _shown;

  static bool _showing(AppLifecycleState? state) => switch (state) {
    null || AppLifecycleState.resumed || AppLifecycleState.inactive => true,
    AppLifecycleState.hidden ||
    AppLifecycleState.paused ||
    AppLifecycleState.detached => false,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _shown = _showing(WidgetsBinding.instance.lifecycleState);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced =
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false) || _debugStill;
    _ticking = TickerMode.valuesOf(context).enabled;
    _sync();
  }

  @override
  void didUpdateWidget(NightSky oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.holdComets && !oldWidget.holdComets) {
      _flight.stop();
      _comet = null;
      _sync();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final bool shown = _showing(state);
    if (shown == _shown) {
      return;
    }
    setState(() => _shown = shown);
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _twinkleTimer?.cancel();
    _cometTimer?.cancel();
    _flight.dispose();
    _twinkleSeconds.dispose();
    super.dispose();
  }

  void _sync() {
    if (!_moving) {
      _twinkleTimer?.cancel();
      _twinkleTimer = null;
      _cometTimer?.cancel();
      _cometTimer = null;
      _flight.stop();
      _comet = null;
      return;
    }
    _twinkleTimer ??= Timer.periodic(nightSkyTwinkleStep, _twinkle);
    if (_cometTimer == null && _comet == null) {
      _cometTimer = Timer(_nextCometWait(), _launch);
    }
  }

  Duration _nextCometWait() {
    if (!_waitedFirst) {
      _waitedFirst = true;
      return nightSkyCometQuiet +
          Duration(
            milliseconds:
                (_cometRandom.nextDouble() *
                        _firstCometSpreadSeconds *
                        Duration.millisecondsPerSecond)
                    .round(),
          );
    }
    return Duration(
      milliseconds:
          ((_cometGapFloorSeconds +
                      _cometRandom.nextDouble() * _cometGapSpreadSeconds) *
                  Duration.millisecondsPerSecond)
              .round(),
    );
  }

  void _twinkle(Timer _) {
    _twinkleSeconds.value +=
        nightSkyTwinkleStep.inMicroseconds / Duration.microsecondsPerSecond;
  }

  void _launch() {
    _cometTimer = null;
    if (!mounted || !_moving) {
      return;
    }
    if (widget.holdComets) {
      _sync();
      return;
    }
    setState(() => _comet = _Comet.draw(_cometRandom));
    unawaited(_flight.forward(from: 0));
  }

  void _onFlight(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) {
      return;
    }
    setState(() => _comet = null);
    _sync();
  }

  NightSkyField _fieldFor(Size size) {
    final NightSkyField? field = _field;
    if (field != null && _fieldSize == size) {
      return field;
    }
    _fieldSize = size;
    return _field = NightSkyField.scatter(
      seed: _seed,
      kind: widget.kind,
      size: size,
    );
  }

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final bool dotted = Theme.of(context).brightness == Brightness.light;
    final bool moving = _moving;
    final _Comet? comet = _comet;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final Size size = constraints.biggest;
              final NightSkyField field = _fieldFor(
                size.isFinite ? size : Size.zero,
              );
              return Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  RepaintBoundary(
                    child: CustomPaint(
                      key: nightSkyStillKey,
                      painter: _StillSkyPainter(
                        field: field,
                        ink: colors.skyStar,
                        withTwinkles: !moving,
                      ),
                    ),
                  ),
                  if (moving && field.twinkling.isNotEmpty)
                    RepaintBoundary(
                      child: CustomPaint(
                        key: nightSkyTwinkleKey,
                        painter: _TwinklePainter(
                          stars: field.twinkling,
                          ink: colors.skyStar,
                          seconds: _twinkleSeconds,
                        ),
                      ),
                    ),
                  if (comet != null)
                    RepaintBoundary(
                      child: CustomPaint(
                        key: nightSkyCometKey,
                        painter: _CometPainter(
                          comet: comet,
                          flight: _flight,
                          ink: colors.skyComet,
                          dotted: dotted,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

Offset _placed(Offset share, Size size) =>
    Offset(share.dx * size.width, share.dy * size.height);

Color _faded(Color ink, double share) =>
    ink.withValues(alpha: (ink.a * share).clamp(0.0, 1.0));

class _StillSkyPainter extends CustomPainter {
  const _StillSkyPainter({
    required this.field,
    required this.ink,
    required this.withTwinkles,
  });

  final NightSkyField field;
  final Color ink;
  final bool withTwinkles;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final Paint paint = Paint();
    for (final NightSkyStar star in field.stars) {
      if (star.twinkle != null && !withTwinkles) {
        continue;
      }
      paint.color = _faded(ink, star.strength);
      canvas.drawCircle(_placed(star.position, size), star.diameter / 2, paint);
    }
    paint.color = _faded(ink, _sparkleStrength);
    for (final NightSkySparkle sparkle in field.sparkles) {
      canvas.drawPath(
        _sparklePath(_placed(sparkle.position, size), sparkle.size),
        paint,
      );
    }
  }

  Path _sparklePath(Offset centre, double size) {
    final double arm = size / 2;
    final double waist = size * _sparkleWaist;
    return Path()
      ..moveTo(centre.dx, centre.dy - arm)
      ..lineTo(centre.dx + waist, centre.dy - waist)
      ..lineTo(centre.dx + arm, centre.dy)
      ..lineTo(centre.dx + waist, centre.dy + waist)
      ..lineTo(centre.dx, centre.dy + arm)
      ..lineTo(centre.dx - waist, centre.dy + waist)
      ..lineTo(centre.dx - arm, centre.dy)
      ..lineTo(centre.dx - waist, centre.dy - waist)
      ..close();
  }

  @override
  bool shouldRepaint(_StillSkyPainter oldDelegate) =>
      !identical(oldDelegate.field, field) ||
      oldDelegate.ink != ink ||
      oldDelegate.withTwinkles != withTwinkles;
}

class _TwinklePainter extends CustomPainter {
  _TwinklePainter({
    required this.stars,
    required this.ink,
    required this.seconds,
  }) : super(repaint: seconds);

  final List<NightSkyStar> stars;
  final Color ink;
  final ValueListenable<double> seconds;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final double now = seconds.value;
    final Paint paint = Paint();
    for (final NightSkyStar star in stars) {
      final double share = star.twinkle?.shareAt(now) ?? 1;
      paint.color = _faded(ink, star.strength * share);
      canvas.drawCircle(_placed(star.position, size), star.diameter / 2, paint);
    }
  }

  @override
  bool shouldRepaint(_TwinklePainter oldDelegate) =>
      !identical(oldDelegate.stars, stars) || oldDelegate.ink != ink;
}

class _CometPainter extends CustomPainter {
  _CometPainter({
    required this.comet,
    required this.flight,
    required this.ink,
    required this.dotted,
  }) : super(repaint: flight);

  final _Comet comet;
  final Animation<double> flight;
  final Color ink;
  final bool dotted;

  double _glowAt(double t) {
    if (t < _cometRise) {
      return t / _cometRise;
    }
    if (t > _cometFall) {
      return (1 - t) / (1 - _cometFall);
    }
    return 1;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double t = flight.value;
    final double glow = _glowAt(t);
    if (size.isEmpty || glow <= 0) {
      return;
    }
    final Offset head =
        _placed(comet.start, size) +
        comet.heading * (comet.travel * _cometCurve.transform(t));
    final Offset tail = head - comet.heading * _cometTail;
    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt
      ..strokeWidth = _cometWidth;
    if (dotted) {
      _paintDashes(canvas, stroke, tail, glow);
    } else {
      _paintStreak(canvas, stroke, tail, head, glow);
      canvas.drawCircle(
        head,
        _cometHaloRadius,
        Paint()
          ..color = _faded(ink, glow * _cometHaloShare)
          ..maskFilter = const MaskFilter.blur(
            BlurStyle.normal,
            _cometHaloBlur,
          ),
      );
    }
    canvas.drawCircle(
      head,
      _cometHeadRadius,
      Paint()..color = _faded(ink, glow),
    );
  }

  double _streakShare(double along) => along < _streakBend
      ? _streakBendShare * along / _streakBend
      : _streakBendShare +
            (_streakHeadShare - _streakBendShare) *
                (along - _streakBend) /
                (1 - _streakBend);

  void _paintStreak(
    Canvas canvas,
    Paint stroke,
    Offset tail,
    Offset head,
    double glow,
  ) {
    final Offset span = head - tail;
    for (int index = 0; index < _cometSegments; index++) {
      final double from = index / _cometSegments;
      final double to = (index + 1) / _cometSegments;
      stroke.color = _faded(ink, glow * _streakShare((from + to) / 2));
      canvas.drawLine(tail + span * from, tail + span * to, stroke);
    }
  }

  void _paintDashes(Canvas canvas, Paint stroke, Offset tail, double glow) {
    stroke.color = _faded(ink, glow * _dashShare);
    for (double along = 0; along < _cometTail; along += _dashPitch) {
      canvas.drawLine(
        tail + comet.heading * along,
        tail + comet.heading * (along + _dashLength),
        stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_CometPainter oldDelegate) =>
      !identical(oldDelegate.comet, comet) ||
      oldDelegate.ink != ink ||
      oldDelegate.dotted != dotted;
}
