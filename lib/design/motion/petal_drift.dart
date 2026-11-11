import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'package:field_notes/design/flowers/petal_art.dart';
import 'package:field_notes/domain/mood/flower_kind.dart';

const double _entryLeft = -20;
const double _exitReach = 60;
const double _topInset = 50;
const double _topReserve = 200;
const double _fallMin = 60;
const double _fallRange = 150;

const double _midway = 0.5;
const double _midwayFall = 0.35;
const double _turnRadians = 400 * math.pi / 180;
const double _fadeInEnd = 0.06;
const double _fadeOutStart = 0.94;
const double _peakOpacity = 0.9;
const double _lateOpacity = 0.85;
const double _appearSeconds = 0.6;

const double _wideArea = 600;

class _Pace {
  const _Pace({
    required this.screen,
    required this.count,
    required this.seed,
    required this.shortestSeconds,
    required this.spreadSeconds,
  });

  final PetalScreen screen;
  final int count;
  final int seed;
  final double shortestSeconds;
  final double spreadSeconds;
}

const _Pace _widePace = _Pace(
  screen: PetalScreen.wide,
  count: 6,
  seed: 13,
  shortestSeconds: 17,
  spreadSeconds: 12,
);
const _Pace _narrowPace = _Pace(
  screen: PetalScreen.narrow,
  count: 4,
  seed: 29,
  shortestSeconds: 11,
  spreadSeconds: 7,
);

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

_Petal _petal(math.Random random, _Pace pace) {
  final double loopSeconds =
      pace.shortestSeconds + random.nextDouble() * pace.spreadSeconds;
  final double top = random.nextDouble();
  final double fall = _fallMin + random.nextDouble() * _fallRange;
  return _Petal(
    loopSeconds: loopSeconds,
    top: top,
    fall: fall,
    phase: random.nextDouble(),
  );
}

List<_Petal> _scatter(_Pace pace) {
  final math.Random random = math.Random(pace.seed);
  return List<_Petal>.unmodifiable(<_Petal>[
    for (int index = 0; index < pace.count; index++) _petal(random, pace),
  ]);
}

final List<_Petal> _widePetals = _scatter(_widePace);
final List<_Petal> _narrowPetals = _scatter(_narrowPace);

@immutable
class _PetalSet {
  const _PetalSet({required this.pace, required this.petals});

  final _Pace pace;
  final List<_Petal> petals;
}

final _PetalSet _wideSet = _PetalSet(pace: _widePace, petals: _widePetals);
final _PetalSet _narrowSet = _PetalSet(
  pace: _narrowPace,
  petals: _narrowPetals,
);

_PetalSet _petalSetFor(double width) =>
    width >= _wideArea ? _wideSet : _narrowSet;

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

  List<_Fall> fallsOn(PetalScreen screen) => switch (screen) {
    PetalScreen.wide => wide,
    PetalScreen.narrow => narrow,
  };

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

void _paintPetal(
  Canvas canvas, {
  required Size size,
  required PetalScreen screen,
  required PetalArt art,
  required double progress,
  required double top,
  required double fall,
  required double opacityFactor,
  required bool alternate,
}) {
  final double span = math.max(0, size.height - _topReserve);
  final double travel = size.width + _exitReach;
  final Size box = art.sizeOn(screen);
  final Offset centre = Offset(
    _entryLeft + box.width / 2 + travel * progress,
    _topInset + top * span + box.height / 2 + _fallAt(progress, fall),
  );
  canvas
    ..save()
    ..translate(centre.dx, centre.dy)
    ..rotate(_turnRadians * progress);
  art.paint(
    canvas,
    opacity: _opacityAt(progress) * opacityFactor,
    size: box,
    alternate: alternate,
  );
  canvas.restore();
}

enum PetalRhythm { steady, gusts }

class PetalDrift extends StatelessWidget {
  const PetalDrift({super.key, this.flower, this.rhythm = PetalRhythm.steady});

  final FlowerKind? flower;
  final PetalRhythm rhythm;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: switch (rhythm) {
          PetalRhythm.steady => _SteadyDrift(flower: flower),
          PetalRhythm.gusts => _GustDrift(flower: flower),
        },
      ),
    );
  }
}

class _SteadyDrift extends StatefulWidget {
  const _SteadyDrift({required this.flower});

  final FlowerKind? flower;

  @override
  State<_SteadyDrift> createState() => _SteadyDriftState();
}

class _SteadyDriftState extends State<_SteadyDrift>
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
  void didUpdateWidget(_SteadyDrift oldWidget) {
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
    return MediaQuery.disableAnimationsOf(context)
        ? const SizedBox.expand()
        : RepaintBoundary(
            child: CustomPaint(
              painter: _PetalPainter(shed: _shed),
              child: const SizedBox.expand(),
            ),
          );
  }
}

class _PetalPainter extends CustomPainter {
  _PetalPainter({required this.shed}) : super(repaint: shed);

  final ValueListenable<_Shed> shed;

  @override
  void paint(Canvas canvas, Size size) {
    final _PetalSet set = _petalSetFor(size.width);
    final PetalScreen screen = set.pace.screen;
    final _Shed now = shed.value;
    final List<_Fall> falls = now.fallsOn(screen);
    if (falls.every((_Fall fall) => fall.art == null)) {
      return;
    }
    canvas.clipRect(Offset.zero & size);
    for (int index = 0; index < set.petals.length; index++) {
      final _Petal petal = set.petals[index];
      final _Fall fall = falls[index];
      final PetalArt? art = fall.art;
      if (art == null) {
        continue;
      }
      _paintPetal(
        canvas,
        size: size,
        screen: screen,
        art: art,
        progress: petal.progressAt(now.seconds),
        top: petal.top,
        fall: petal.fall,
        opacityFactor: fall.revealAt(now.seconds),
        alternate: index.isOdd,
      );
    }
  }

  @override
  bool shouldRepaint(_PetalPainter oldDelegate) => oldDelegate.shed != shed;
}

const int _restLeastGusts = 5;

@immutable
class _Flight {
  const _Flight({
    required this.entry,
    required this.top,
    this.entered = false,
    this.art,
  });

  final double entry;
  final double top;
  final bool entered;
  final PetalArt? art;

  double progressAt(_Petal petal, double seconds) =>
      (seconds - entry) / petal.loopSeconds;

  bool leftAt(_Petal petal, double seconds) => progressAt(petal, seconds) >= 1;

  bool airborneAt(_Petal petal, double seconds) =>
      entered && art != null && !leftAt(petal, seconds);

  _Flight at(double seconds, PetalArt? current) => entered || seconds < entry
      ? this
      : _Flight(entry: entry, top: top, entered: true, art: current);
}

@immutable
class _Gust {
  const _Gust({
    required this.set,
    required this.flower,
    required this.flights,
    required this.seconds,
  });

  factory _Gust.start(_PetalSet set, FlowerKind flower, math.Random random) {
    final double spread = set.pace.shortestSeconds / 4;
    return _Gust(
      set: set,
      flower: flower,
      seconds: 0,
      flights: List<_Flight>.unmodifiable(<_Flight>[
        for (int index = 0; index < set.petals.length; index++)
          _Flight(
            entry: random.nextDouble() * spread,
            top: random.nextDouble(),
          ),
      ]),
    );
  }

  final _PetalSet set;
  final FlowerKind flower;
  final List<_Flight> flights;
  final double seconds;

  double get length => <double>[
    for (int index = 0; index < flights.length; index++)
      flights[index].entry + set.petals[index].loopSeconds,
  ].reduce(math.max);

  bool get spent => <bool>[
    for (int index = 0; index < flights.length; index++)
      flights[index].leftAt(set.petals[index], seconds),
  ].every((bool left) => left);

  bool get empty => <bool>[
    for (int index = 0; index < flights.length; index++)
      flights[index].airborneAt(set.petals[index], seconds),
  ].every((bool airborne) => !airborne);

  _Gust at(double now, PetalArt? current) => _Gust(
    set: set,
    flower: flower,
    seconds: now,
    flights: List<_Flight>.unmodifiable(<_Flight>[
      for (final _Flight flight in flights) flight.at(now, current),
    ]),
  );
}

class _GustDrift extends StatefulWidget {
  const _GustDrift({required this.flower});

  final FlowerKind? flower;

  @override
  State<_GustDrift> createState() => _GustDriftState();
}

class _GustDriftState extends State<_GustDrift>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<_Gust?> _gust = ValueNotifier<_Gust?>(null);
  final math.Random _random = math.Random();
  late final Ticker _ticker = createTicker(_tick);
  Timer? _rest;
  Duration _origin = Duration.zero;
  _PetalSet? _laidOut;
  bool? _still;

  PetalArt? get _current {
    final FlowerKind? flower = widget.flower;
    return flower == null ? null : petalArtFor(flower);
  }

  void _blow() {
    _rest?.cancel();
    _rest = null;
    _gust.value = null;
    if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  void _halt() {
    _rest?.cancel();
    _rest = null;
    _gust.value = null;
    _ticker.stop();
  }

  void _restAfter(_Gust gust) {
    _halt();
    final double gusts = _restLeastGusts + _random.nextDouble();
    _rest = Timer(
      Duration(
        microseconds: (gust.length * gusts * Duration.microsecondsPerSecond)
            .round(),
      ),
      _restEnded,
    );
  }

  void _restEnded() {
    _rest = null;
    if (widget.flower != null && !MediaQuery.disableAnimationsOf(context)) {
      _blow();
    }
  }

  void _tick(Duration elapsed) {
    final _PetalSet? set = _laidOut;
    if (set == null) {
      return;
    }
    final FlowerKind? flower = widget.flower;
    final _Gust? gust = _gust.value;
    if (gust == null || !identical(gust.set, set)) {
      if (flower == null) {
        _halt();
        return;
      }
      _origin = elapsed;
      _gust.value = _Gust.start(set, flower, _random);
      return;
    }
    final double seconds =
        (elapsed - _origin).inMicroseconds / Duration.microsecondsPerSecond;
    final _Gust moved = gust.at(seconds, _current);
    if (flower == null && moved.empty) {
      _halt();
    } else if (!moved.spent) {
      _gust.value = moved;
    } else if (flower != moved.flower) {
      _gust.value = null;
    } else {
      _restAfter(moved);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool still = MediaQuery.disableAnimationsOf(context);
    if (still == _still) {
      return;
    }
    _still = still;
    if (still) {
      _halt();
    } else if (widget.flower != null) {
      _blow();
    }
  }

  @override
  void didUpdateWidget(_GustDrift oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.flower == oldWidget.flower ||
        MediaQuery.disableAnimationsOf(context)) {
      return;
    }
    if (widget.flower == null) {
      _rest?.cancel();
      _rest = null;
    } else if (!_ticker.isActive) {
      _blow();
    }
  }

  @override
  void dispose() {
    _rest?.cancel();
    _ticker.dispose();
    _gust.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return const SizedBox.expand();
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final _PetalSet set = _petalSetFor(constraints.maxWidth);
        _laidOut = set;
        return RepaintBoundary(
          child: CustomPaint(
            painter: _GustPainter(gust: _gust, set: set),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }
}

class _GustPainter extends CustomPainter {
  _GustPainter({required this.gust, required this.set}) : super(repaint: gust);

  final ValueListenable<_Gust?> gust;
  final _PetalSet set;

  @override
  void paint(Canvas canvas, Size size) {
    final _Gust? now = gust.value;
    if (now == null || !identical(now.set, set) || now.empty) {
      return;
    }
    canvas.clipRect(Offset.zero & size);
    for (int index = 0; index < set.petals.length; index++) {
      final _Petal petal = set.petals[index];
      final _Flight flight = now.flights[index];
      final PetalArt? art = flight.art;
      if (art == null || !flight.airborneAt(petal, now.seconds)) {
        continue;
      }
      _paintPetal(
        canvas,
        size: size,
        screen: set.pace.screen,
        art: art,
        progress: flight.progressAt(petal, now.seconds),
        top: flight.top,
        fall: petal.fall,
        opacityFactor: 1,
        alternate: index.isOdd,
      );
    }
  }

  @override
  bool shouldRepaint(_GustPainter oldDelegate) =>
      oldDelegate.gust != gust || !identical(oldDelegate.set, set);
}
