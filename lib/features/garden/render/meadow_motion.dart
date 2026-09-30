import 'dart:math' as math;

import 'package:flutter/animation.dart';

const double meadowSwayPeriod = 9;
const double meadowGrassPeriod = 9;
const double meadowCrownPeriod = 11;
const double meadowWingPeriod = 0.13;
const double meadowTwinklePeriod = 3;
const double meadowLakeMistPeriod = 40;
const double meadowFallMistPeriod = 18;
const double meadowFallTravel = 28;
const double meadowRaysPeriod = 9;
const double meadowShootingPeriod = 19;
const double meadowShootingDelay = 6;
const double meadowShootingTravel = 240;
const double meadowGrowSeconds = 1;
const double meadowHighlightSeconds = 0.35;
const double meadowRevealSeconds = 1.6;

const double _degrees = math.pi / 180;
const double _growFrom = 0.04;
const double _growOpaque = 0.35;
const Cubic _growCurve = Cubic(0.2, 0.9, 0.3, 1.12);

const List<_Key> _swayKeys = <_Key>[
  _Key(0, -1.1),
  _Key(0.14, 1.2),
  _Key(0.28, -0.8),
  _Key(0.44, 0.9),
  _Key(0.57, 4),
  _Key(0.68, -1.5),
  _Key(0.82, 1.3),
  _Key(1, -1.1),
];
const List<_Key> _grassKeys = <_Key>[
  _Key(0, 2),
  _Key(0.14, -2.5),
  _Key(0.28, 1.5),
  _Key(0.44, -2),
  _Key(0.57, -9),
  _Key(0.68, 3),
  _Key(0.82, -2.5),
  _Key(1, 2),
];
const List<_Key> _crownKeys = <_Key>[
  _Key(0, -0.4),
  _Key(0.57, 1.1),
  _Key(1, -0.4),
];
const List<_Key> _wingKeys = <_Key>[_Key(0, 1), _Key(0.5, 0.42), _Key(1, 1)];
const List<_Key> _twinkleKeys = <_Key>[
  _Key(0, 0.3),
  _Key(0.5, 1),
  _Key(1, 0.3),
];
const List<_Key> _cloudKeys = <_Key>[_Key(0, -40), _Key(1, 60)];
const List<_Key> _mistKeys = <_Key>[_Key(0, -26), _Key(0.5, 30), _Key(1, -26)];
const List<_Key> _rippleScaleKeys = <_Key>[_Key(0, 0.15), _Key(1, 1.5)];
const List<_Key> _rippleOpacityKeys = <_Key>[
  _Key(0, 0),
  _Key(0.08, 0.9),
  _Key(0.55, 0),
  _Key(1, 0),
];
const List<_Key> _flowShiftKeys = <_Key>[_Key(0, -5), _Key(1, 9)];
const List<_Key> _flowOpacityKeys = <_Key>[
  _Key(0, 0),
  _Key(0.35, 1),
  _Key(1, 0),
];
const List<_Key> _glintKeys = <_Key>[_Key(0, 0), _Key(0.5, 1), _Key(1, 0)];
const List<_Key> _breathKeys = <_Key>[
  _Key(0, 0.78),
  _Key(0.5, 1),
  _Key(1, 0.78),
];
const List<_Key> _shootingShiftKeys = <_Key>[
  _Key(0, 0),
  _Key(0.93, 0),
  _Key(0.98, -meadowShootingTravel),
  _Key(1, -meadowShootingTravel),
];
const List<_Key> _shootingOpacityKeys = <_Key>[
  _Key(0, 0),
  _Key(0.93, 0),
  _Key(0.94, 1),
  _Key(0.98, 0),
  _Key(1, 0),
];

class _Key {
  const _Key(this.at, this.value);

  final double at;
  final double value;
}

double _cycle(double time, double period) {
  final double turns = time / period;
  return turns - turns.floorToDouble();
}

double _between(List<_Key> keys, double progress, Curve curve) {
  int i = 0;
  while (i < keys.length - 2 && progress >= keys[i + 1].at) {
    i++;
  }
  final _Key from = keys[i];
  final _Key to = keys[i + 1];
  final double local = ((progress - from.at) / (to.at - from.at)).clamp(
    0.0,
    1.0,
  );
  return from.value + (to.value - from.value) * curve.transform(local);
}

double meadowSwayAngle(double time) =>
    _between(_swayKeys, _cycle(time, meadowSwayPeriod), Curves.easeInOut) *
    _degrees;

double meadowGrassSkew(double time) =>
    _between(_grassKeys, _cycle(time, meadowGrassPeriod), Curves.easeInOut) *
    _degrees;

double meadowCrownAngle(double time) =>
    _between(_crownKeys, _cycle(time, meadowCrownPeriod), Curves.easeInOut) *
    _degrees;

double meadowWingFlap(double time, {double period = meadowWingPeriod}) =>
    _between(_wingKeys, _cycle(time, period), Curves.easeInOut);

double meadowTwinkle(double time, {double period = meadowTwinklePeriod}) =>
    _between(_twinkleKeys, _cycle(time, period), Curves.easeInOut);

double meadowCloudDrift(
  double time, {
  required double period,
  double phase = 0,
}) {
  final double turns = (time + phase) / period;
  final double progress = turns - turns.floorToDouble();
  final bool returning = turns.floor().isOdd;
  return _between(
    _cloudKeys,
    returning ? 1 - progress : progress,
    Curves.easeInOut,
  );
}

double meadowMistDrift(
  double time, {
  required double period,
  double phase = 0,
}) => _between(_mistKeys, _cycle(time + phase, period), Curves.easeInOut);

({double scale, double opacity}) meadowRipple(
  double time, {
  required double period,
  double phase = 0,
}) {
  final double progress = _cycle(time + phase, period);
  return (
    scale: _between(_rippleScaleKeys, progress, Curves.easeOut),
    opacity: _between(_rippleOpacityKeys, progress, Curves.easeOut),
  );
}

({double shift, double opacity}) meadowFlow(
  double time, {
  required double period,
  double phase = 0,
}) {
  final double progress = _cycle(time + phase, period);
  return (
    shift: _between(_flowShiftKeys, progress, Curves.linear),
    opacity: _between(_flowOpacityKeys, progress, Curves.linear),
  );
}

double meadowFallOffset(
  double time, {
  required double period,
  double phase = 0,
}) => meadowFallTravel * _cycle(time + phase, period);

double meadowGlint(double time, {required double period, double phase = 0}) =>
    _between(_glintKeys, _cycle(time + phase, period), Curves.easeInOut);

double meadowRaysBreath(double time) =>
    _between(_breathKeys, _cycle(time, meadowRaysPeriod), Curves.easeInOut);

({double shift, double opacity}) meadowShootingStar(double time) {
  final double progress = _cycle(
    time + meadowShootingDelay,
    meadowShootingPeriod,
  );
  return (
    shift: _between(_shootingShiftKeys, progress, Curves.linear),
    opacity: _between(_shootingOpacityKeys, progress, Curves.linear),
  );
}

({double scale, double opacity}) meadowGrowIn(double elapsed) {
  final double progress = (elapsed / meadowGrowSeconds).clamp(0.0, 1.0);
  final double opacity = progress >= _growOpaque
      ? 1
      : _growCurve.transform(progress / _growOpaque).clamp(0.0, 1.0);
  return (
    scale: _growFrom + (1 - _growFrom) * _growCurve.transform(progress),
    opacity: opacity,
  );
}

double meadowFade(double elapsed, double seconds) =>
    Curves.ease.transform((elapsed / seconds).clamp(0.0, 1.0));
