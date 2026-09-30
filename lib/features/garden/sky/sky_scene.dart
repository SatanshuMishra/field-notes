import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:field_notes/features/garden/sky/sky_astronomy.dart';

const double skyWarmGlowY = 0.33;

class _Rgb {
  const _Rgb(this.red, this.green, this.blue);

  final int red;
  final int green;
  final int blue;

  _Rgb lerpTo(_Rgb other, double t) => _Rgb(
    (red + (other.red - red) * t).round(),
    (green + (other.green - green) * t).round(),
    (blue + (other.blue - blue) * t).round(),
  );

  Color withAlpha(double alpha) => Color.fromRGBO(red, green, blue, alpha);
}

class _SkyKeyframe {
  const _SkyKeyframe(this.altitude, this.top, this.middle, this.horizon);

  final double altitude;
  final _Rgb top;
  final _Rgb middle;
  final _Rgb horizon;
}

const List<_SkyKeyframe> _skyKeyframes = <_SkyKeyframe>[
  _SkyKeyframe(-14, _Rgb(12, 16, 34), _Rgb(22, 28, 56), _Rgb(38, 44, 76)),
  _SkyKeyframe(-8, _Rgb(20, 26, 56), _Rgb(46, 50, 92), _Rgb(92, 80, 114)),
  _SkyKeyframe(-3, _Rgb(46, 58, 106), _Rgb(138, 110, 142), _Rgb(222, 148, 122)),
  _SkyKeyframe(
    2,
    _Rgb(150, 160, 192),
    _Rgb(234, 196, 162),
    _Rgb(244, 184, 134),
  ),
  _SkyKeyframe(
    10,
    _Rgb(204, 214, 216),
    _Rgb(232, 226, 208),
    _Rgb(240, 226, 196),
  ),
  _SkyKeyframe(
    20,
    _Rgb(190, 210, 222),
    _Rgb(224, 228, 218),
    _Rgb(238, 232, 210),
  ),
];

const _Rgb _sunHigh = _Rgb(244, 201, 96);
const _Rgb _sunLow = _Rgb(238, 124, 74);
const _Rgb _warmGlow = _Rgb(250, 176, 120);
const _Rgb _poolDark = _Rgb(22, 28, 60);
const _Rgb _poolLit = _Rgb(178, 190, 236);
const _Rgb _nightEdge = _Rgb(20, 26, 58);
const _Rgb _warmTint = _Rgb(236, 150, 104);
const Color _nightCaption = Color.fromRGBO(236, 230, 214, 0.82);
const Color _dayCaption = Color.fromRGBO(60, 48, 36, 0.72);

class SkyGradient {
  const SkyGradient({
    required this.top,
    required this.middle,
    required this.horizon,
  });

  final Color top;
  final Color middle;
  final Color horizon;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SkyGradient &&
          runtimeType == other.runtimeType &&
          top == other.top &&
          middle == other.middle &&
          horizon == other.horizon;

  @override
  int get hashCode => Object.hash(top, middle, horizon);

  @override
  String toString() =>
      'SkyGradient(top: $top, middle: $middle, horizon: $horizon)';
}

SkyGradient skyGradientAt(double sunAltitude) {
  int i = 0;
  while (i < _skyKeyframes.length - 2 &&
      sunAltitude > _skyKeyframes[i + 1].altitude) {
    i++;
  }
  final _SkyKeyframe from = _skyKeyframes[i];
  final _SkyKeyframe to = _skyKeyframes[i + 1];
  final double k =
      ((sunAltitude - from.altitude) / (to.altitude - from.altitude)).clamp(
        0.0,
        1.0,
      );
  return SkyGradient(
    top: from.top.lerpTo(to.top, k).withAlpha(1),
    middle: from.middle.lerpTo(to.middle, k).withAlpha(1),
    horizon: from.horizon.lerpTo(to.horizon, k).withAlpha(1),
  );
}

double skyNightWeight(double sunAltitude) =>
    ((2 - sunAltitude) / 12).clamp(0.0, 1.0);

double skyWarmWeight(double sunAltitude) =>
    math.max(0.0, 1 - (sunAltitude - 2).abs() / 9);

double skyLowWeight(double sunAltitude) =>
    (1 - sunAltitude / 14).clamp(0.0, 1.0);

double skyScreenX(double azimuth, double latitude) {
  final double v = latitude < 0
      ? -(azimuth > 0 ? math.pi - azimuth : -math.pi - azimuth)
      : azimuth;
  return (50 + (v / (math.pi * 0.62)).clamp(-1.0, 1.0) * 45) / 100;
}

double skyScreenY(double altitude) =>
    (31 - (altitude / 62).clamp(-1.3, 1.0) * 23) / 100;

class SkyScene {
  const SkyScene({
    required this.sunAltitude,
    required this.moonAltitude,
    required this.gradient,
    required this.night,
    required this.warm,
    required this.low,
    required this.sunX,
    required this.sunY,
    required this.sunColour,
    required this.warmGlow,
    required this.moonX,
    required this.moonY,
    required this.moonUp,
    required this.moonFraction,
    required this.moonPhase,
    required this.moonOpacity,
    required this.moonGlowAlpha,
    required this.moonShadeOffset,
    required this.moonPool,
    required this.nightEdge,
    required this.warmTint,
    required this.starsOpacity,
    required this.hazeOpacity,
    required this.firefliesOpacity,
    required this.dayLifeOpacity,
    required this.captionColour,
    required this.phaseName,
  });

  final double sunAltitude;
  final double moonAltitude;
  final SkyGradient gradient;
  final double night;
  final double warm;
  final double low;
  final double sunX;
  final double sunY;
  final Color sunColour;
  final Color warmGlow;
  final double moonX;
  final double moonY;
  final bool moonUp;
  final double moonFraction;
  final double moonPhase;
  final double moonOpacity;
  final double moonGlowAlpha;
  final double moonShadeOffset;
  final Color moonPool;
  final Color nightEdge;
  final Color? warmTint;
  final double starsOpacity;
  final double hazeOpacity;
  final double firefliesOpacity;
  final double dayLifeOpacity;
  final Color captionColour;
  final String phaseName;

  Color get skyTop => gradient.top;

  Color get skyMiddle => gradient.middle;

  Color get skyHorizon => gradient.horizon;

  double get warmGlowX => sunX;

  double get warmGlowY => skyWarmGlowY;

  double get warmGlowAlpha => warmGlow.a;

  double get moonPoolAlpha => moonPool.a;

  double get nightEdgeAlpha => nightEdge.a;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SkyScene &&
          runtimeType == other.runtimeType &&
          sunAltitude == other.sunAltitude &&
          moonAltitude == other.moonAltitude &&
          gradient == other.gradient &&
          night == other.night &&
          warm == other.warm &&
          low == other.low &&
          sunX == other.sunX &&
          sunY == other.sunY &&
          sunColour == other.sunColour &&
          warmGlow == other.warmGlow &&
          moonX == other.moonX &&
          moonY == other.moonY &&
          moonUp == other.moonUp &&
          moonFraction == other.moonFraction &&
          moonPhase == other.moonPhase &&
          moonOpacity == other.moonOpacity &&
          moonGlowAlpha == other.moonGlowAlpha &&
          moonShadeOffset == other.moonShadeOffset &&
          moonPool == other.moonPool &&
          nightEdge == other.nightEdge &&
          warmTint == other.warmTint &&
          starsOpacity == other.starsOpacity &&
          hazeOpacity == other.hazeOpacity &&
          firefliesOpacity == other.firefliesOpacity &&
          dayLifeOpacity == other.dayLifeOpacity &&
          captionColour == other.captionColour &&
          phaseName == other.phaseName;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    sunAltitude,
    moonAltitude,
    gradient,
    night,
    warm,
    low,
    sunX,
    sunY,
    sunColour,
    warmGlow,
    moonX,
    moonY,
    moonUp,
    moonFraction,
    moonPhase,
    moonOpacity,
    moonGlowAlpha,
    moonShadeOffset,
    moonPool,
    nightEdge,
    warmTint,
    starsOpacity,
    hazeOpacity,
    firefliesOpacity,
    dayLifeOpacity,
    captionColour,
    phaseName,
  ]);
}

SkyScene skySceneAt(DateTime instant, double latitude, double longitude) {
  final SkyPosition sun = sunPosition(instant, latitude, longitude);
  final SkyPosition moon = moonPosition(instant, latitude, longitude);
  final MoonIllumination illumination = moonIllumination(instant);
  final double a = sun.altitude;
  final double night = skyNightWeight(a);
  final double warm = skyWarmWeight(a);
  final double low = skyLowWeight(a);
  final bool moonUp = moon.altitude > 0;
  final _Rgb pool = moonUp
      ? _poolDark.lerpTo(_poolLit, 0.55 + 0.45 * illumination.fraction)
      : _poolDark;
  return SkyScene(
    sunAltitude: a,
    moonAltitude: moon.altitude,
    gradient: skyGradientAt(a),
    night: night,
    warm: warm,
    low: low,
    sunX: skyScreenX(sun.azimuth, latitude),
    sunY: skyScreenY(a),
    sunColour: _sunHigh.lerpTo(_sunLow, low).withAlpha(1),
    warmGlow: _warmGlow.withAlpha(0.55 * warm),
    moonX: skyScreenX(moon.azimuth, latitude),
    moonY: skyScreenY(moon.altitude),
    moonUp: moonUp,
    moonFraction: illumination.fraction,
    moonPhase: illumination.phase,
    moonOpacity: 0.4 + 0.6 * night,
    moonGlowAlpha: 0.12 + 0.5 * night * (0.4 + 0.6 * illumination.fraction),
    moonShadeOffset:
        (illumination.phase < 0.5 ? -1 : 1) * illumination.fraction,
    moonPool: pool.withAlpha(0.8 * night),
    nightEdge: _nightEdge.withAlpha(0.82 * night),
    warmTint: warm > 0.02 ? _warmTint.withAlpha(0.3 * warm) : null,
    starsOpacity: ((-a - 4) / 8).clamp(0.0, 1.0),
    hazeOpacity: 1 - 0.85 * night,
    firefliesOpacity: ((night - 0.4) / 0.6).clamp(0.0, 1.0),
    dayLifeOpacity: 1 - (night / 0.7).clamp(0.0, 1.0),
    captionColour: night > 0.55 ? _nightCaption : _dayCaption,
    phaseName: moonPhaseName(illumination.phase),
  );
}
