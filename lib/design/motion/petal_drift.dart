import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

const Color _petalPink = Color(0xFFF2A9B2);
const Color _petalRose = Color(0xFFED97A4);
const Color _petalEdge = Color(0x598A4A4A);

const double _petalWidth = 10;
const double _petalHeight = 7;
const double _edgeWidth = 1;
const Radius _broadCorner = Radius.elliptical(6, 4.2);
const Radius _narrowCorner = Radius.elliptical(4, 2.8);

const double _entryLeft = -20;
const double _exitReach = 60;
const double _topInset = 50;
const double _topReserve = 200;
const double _fallMin = 60;
const double _fallRange = 150;
const double _loopMinSeconds = 17;
const double _loopRangeSeconds = 12;

const double _midway = 0.5;
const double _midwayFall = 0.35;
const double _turnRadians = 400 * math.pi / 180;
const double _fadeInEnd = 0.06;
const double _fadeOutStart = 0.94;
const double _peakOpacity = 0.9;
const double _lateOpacity = 0.85;

const double _wideArea = 600;
const int _wideCount = 6;
const int _narrowCount = 3;
const int _wideSeed = 13;
const int _narrowSeed = 29;

class _Petal {
  const _Petal({
    required this.loopSeconds,
    required this.top,
    required this.fall,
    required this.phase,
    required this.color,
  });

  final double loopSeconds;
  final double top;
  final double fall;
  final double phase;
  final Color color;
}

_Petal _petal(math.Random random, int index) {
  final double loopSeconds =
      _loopMinSeconds + random.nextDouble() * _loopRangeSeconds;
  final double top = random.nextDouble();
  final double fall = _fallMin + random.nextDouble() * _fallRange;
  return _Petal(
    loopSeconds: loopSeconds,
    top: top,
    fall: fall,
    phase: random.nextDouble(),
    color: index.isOdd ? _petalPink : _petalRose,
  );
}

List<_Petal> _scatter(int count, int seed) {
  final math.Random random = math.Random(seed);
  return List<_Petal>.unmodifiable(<_Petal>[
    for (int index = 0; index < count; index++) _petal(random, index),
  ]);
}

final List<_Petal> _widePetals = _scatter(_wideCount, _wideSeed);
final List<_Petal> _narrowPetals = _scatter(_narrowCount, _narrowSeed);

double _fallAt(double progress, double fall) => progress < _midway
    ? fall * _midwayFall * progress / _midway
    : fall * (_midwayFall + (1 - _midwayFall) * (progress - _midway) / _midway);

double _opacityAt(double progress) {
  if (progress < _fadeInEnd) {
    return _peakOpacity * progress / _fadeInEnd;
  }
  if (progress < _fadeOutStart) {
    return _peakOpacity +
        (_lateOpacity - _peakOpacity) *
            (progress - _fadeInEnd) /
            (_fadeOutStart - _fadeInEnd);
  }
  return _lateOpacity * (1 - progress) / (1 - _fadeOutStart);
}

class PetalDrift extends StatefulWidget {
  const PetalDrift({super.key});

  @override
  State<PetalDrift> createState() => _PetalDriftState();
}

class _PetalDriftState extends State<PetalDrift>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<Duration> _clock = ValueNotifier<Duration>(Duration.zero);
  late final Ticker _ticker = createTicker(_tick);

  void _tick(Duration elapsed) {
    _clock.value = elapsed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool still = MediaQuery.disableAnimationsOf(context);
    if (still && _ticker.isActive) {
      _ticker.stop();
    } else if (!still && !_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: MediaQuery.disableAnimationsOf(context)
            ? const SizedBox.expand()
            : RepaintBoundary(
                child: CustomPaint(
                  painter: _PetalPainter(clock: _clock),
                  child: const SizedBox.expand(),
                ),
              ),
      ),
    );
  }
}

class _PetalPainter extends CustomPainter {
  _PetalPainter({required this.clock}) : super(repaint: clock);

  final ValueListenable<Duration> clock;

  @override
  void paint(Canvas canvas, Size size) {
    final List<_Petal> petals = size.width >= _wideArea
        ? _widePetals
        : _narrowPetals;
    final double seconds =
        clock.value.inMicroseconds / Duration.microsecondsPerSecond;
    final double span = math.max(0, size.height - _topReserve);
    final double travel = size.width + _exitReach;
    canvas.clipRect(Offset.zero & size);
    for (final _Petal petal in petals) {
      final double progress = (seconds / petal.loopSeconds + petal.phase) % 1;
      final Offset centre = Offset(
        _entryLeft + _petalWidth / 2 + travel * progress,
        _topInset +
            petal.top * span +
            _petalHeight / 2 +
            _fallAt(progress, petal.fall),
      );
      _paintPetal(canvas, petal, centre, progress);
    }
  }

  void _paintPetal(
    Canvas canvas,
    _Petal petal,
    Offset centre,
    double progress,
  ) {
    final double opacity = _opacityAt(progress);
    final RRect shape = RRect.fromRectAndCorners(
      Rect.fromCenter(
        center: Offset.zero,
        width: _petalWidth,
        height: _petalHeight,
      ),
      topLeft: _broadCorner,
      topRight: _narrowCorner,
      bottomRight: _broadCorner,
      bottomLeft: _narrowCorner,
    );
    final Paint fill = Paint()
      ..color = petal.color.withValues(alpha: petal.color.a * opacity)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final Paint edge = Paint()
      ..color = _petalEdge.withValues(alpha: _petalEdge.a * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _edgeWidth
      ..isAntiAlias = true;
    canvas
      ..save()
      ..translate(centre.dx, centre.dy)
      ..rotate(_turnRadians * progress)
      ..drawRRect(shape, fill)
      ..drawRRect(shape.deflate(_edgeWidth / 2), edge)
      ..restore();
  }

  @override
  bool shouldRepaint(_PetalPainter oldDelegate) => oldDelegate.clock != clock;
}
