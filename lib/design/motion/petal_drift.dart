import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'package:field_notes/design/flowers/petal_art.dart';
import 'package:field_notes/domain/mood/flower_kind.dart';

const double _petalWidth = 10;
const double _petalHeight = 7;

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
const double _appearSeconds = 0.6;

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
  });

  final double loopSeconds;
  final double top;
  final double fall;
  final double phase;

  double _turnsAt(double seconds) => seconds / loopSeconds + phase;

  int loopAt(double seconds) => _turnsAt(seconds).floor();

  double progressAt(double seconds) => _turnsAt(seconds) % 1;
}

_Petal _petal(math.Random random) {
  final double loopSeconds =
      _loopMinSeconds + random.nextDouble() * _loopRangeSeconds;
  final double top = random.nextDouble();
  final double fall = _fallMin + random.nextDouble() * _fallRange;
  return _Petal(
    loopSeconds: loopSeconds,
    top: top,
    fall: fall,
    phase: random.nextDouble(),
  );
}

List<_Petal> _scatter(int count, int seed) {
  final math.Random random = math.Random(seed);
  return List<_Petal>.unmodifiable(<_Petal>[
    for (int index = 0; index < count; index++) _petal(random),
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

@immutable
class _Fall {
  const _Fall({required this.loop, this.art, this.shownAt});

  final int loop;
  final PetalArt? art;
  final double? shownAt;

  _Fall at(_Petal petal, double seconds, PetalArt? current) {
    final int now = petal.loopAt(seconds);
    return now == loop ? this : _Fall(loop: now, art: current);
  }

  _Fall shownWith(PetalArt current, double seconds) =>
      art == null ? _Fall(loop: loop, art: current, shownAt: seconds) : this;

  double revealAt(double seconds) {
    final double? from = shownAt;
    return from == null
        ? 1
        : clampDouble((seconds - from) / _appearSeconds, 0, 1);
  }
}

bool _turned(List<_Petal> petals, List<_Fall> falls, double seconds) {
  for (int index = 0; index < petals.length; index++) {
    if (petals[index].loopAt(seconds) != falls[index].loop) {
      return true;
    }
  }
  return false;
}

List<_Fall> _falling(
  List<_Petal> petals,
  List<_Fall> falls,
  double seconds,
  PetalArt? current,
) => _turned(petals, falls, seconds)
    ? List<_Fall>.unmodifiable(<_Fall>[
        for (int index = 0; index < petals.length; index++)
          falls[index].at(petals[index], seconds, current),
      ])
    : falls;

@immutable
class _Shed {
  const _Shed({
    required this.seconds,
    required this.wide,
    required this.narrow,
  });

  factory _Shed.start(PetalArt? current) {
    final _Shed bare = _Shed(
      seconds: 0,
      wide: _unshown(_widePetals),
      narrow: _unshown(_narrowPetals),
    );
    return current == null ? bare : bare.shownWith(current);
  }

  final double seconds;
  final List<_Fall> wide;
  final List<_Fall> narrow;

  static List<_Fall> _unshown(List<_Petal> petals) => List<_Fall>.unmodifiable(
    <_Fall>[for (final _Petal petal in petals) _Fall(loop: petal.loopAt(0))],
  );

  bool get bare =>
      wide.every((_Fall fall) => fall.art == null) &&
      narrow.every((_Fall fall) => fall.art == null);

  _Shed at(double now, PetalArt? current) => _Shed(
    seconds: now,
    wide: _falling(_widePetals, wide, now, current),
    narrow: _falling(_narrowPetals, narrow, now, current),
  );

  _Shed shownWith(PetalArt current) => _Shed(
    seconds: seconds,
    wide: List<_Fall>.unmodifiable(<_Fall>[
      for (final _Fall fall in wide) fall.shownWith(current, seconds),
    ]),
    narrow: List<_Fall>.unmodifiable(<_Fall>[
      for (final _Fall fall in narrow) fall.shownWith(current, seconds),
    ]),
  );
}

class PetalDrift extends StatefulWidget {
  const PetalDrift({super.key, this.flower});

  final FlowerKind? flower;

  @override
  State<PetalDrift> createState() => _PetalDriftState();
}

class _PetalDriftState extends State<PetalDrift>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<_Shed> _shed = ValueNotifier<_Shed>(_Shed.start(null));
  late final Ticker _ticker = createTicker(_tick);
  Duration? _origin;

  PetalArt? get _current {
    final FlowerKind? flower = widget.flower;
    return flower == null ? null : petalArtFor(flower);
  }

  double get _now {
    final Duration stamp = SchedulerBinding.instance.currentFrameTimeStamp;
    final Duration origin = _origin ??= stamp;
    return (stamp - origin).inMicroseconds / Duration.microsecondsPerSecond;
  }

  void _tick(Duration _) {
    final PetalArt? current = _current;
    final _Shed shed = _shed.value.at(_now, current);
    _shed.value = shed;
    if (current == null && shed.bare) {
      _ticker.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool still = MediaQuery.disableAnimationsOf(context);
    if (still && _ticker.isActive) {
      _ticker.stop();
    } else if (!still && !_ticker.isActive) {
      final PetalArt? current = _current;
      _origin = null;
      _shed.value = _Shed.start(current);
      if (current != null) {
        _ticker.start();
      }
    }
  }

  @override
  void didUpdateWidget(PetalDrift oldWidget) {
    super.didUpdateWidget(oldWidget);
    final PetalArt? current = _current;
    if (current == null ||
        widget.flower == oldWidget.flower ||
        MediaQuery.disableAnimationsOf(context)) {
      return;
    }
    _shed.value = _shed.value.at(_now, null).shownWith(current);
    if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _shed.dispose();
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
                  painter: _PetalPainter(shed: _shed),
                  child: const SizedBox.expand(),
                ),
              ),
      ),
    );
  }
}

class _PetalPainter extends CustomPainter {
  _PetalPainter({required this.shed}) : super(repaint: shed);

  final ValueListenable<_Shed> shed;

  @override
  void paint(Canvas canvas, Size size) {
    final bool wide = size.width >= _wideArea;
    final List<_Petal> petals = wide ? _widePetals : _narrowPetals;
    final _Shed now = shed.value;
    final List<_Fall> falls = wide ? now.wide : now.narrow;
    if (falls.every((_Fall fall) => fall.art == null)) {
      return;
    }
    final double span = math.max(0, size.height - _topReserve);
    final double travel = size.width + _exitReach;
    canvas.clipRect(Offset.zero & size);
    for (int index = 0; index < petals.length; index++) {
      final _Petal petal = petals[index];
      final _Fall fall = falls[index];
      final PetalArt? art = fall.art;
      if (art == null) {
        continue;
      }
      final double progress = petal.progressAt(now.seconds);
      final Offset centre = Offset(
        _entryLeft + _petalWidth / 2 + travel * progress,
        _topInset +
            petal.top * span +
            _petalHeight / 2 +
            _fallAt(progress, petal.fall),
      );
      canvas
        ..save()
        ..translate(centre.dx, centre.dy)
        ..rotate(_turnRadians * progress);
      art.paint(
        canvas,
        opacity: _opacityAt(progress) * fall.revealAt(now.seconds),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_PetalPainter oldDelegate) => oldDelegate.shed != shed;
}
