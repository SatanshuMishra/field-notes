import 'dart:math' as math;
import 'dart:ui';

import 'package:field_notes/features/garden/scene/meadow_world.dart';
import 'package:field_notes/features/garden/sky/sky_scene.dart';
import 'package:flutter/foundation.dart';

const double meadowWarmGlowY = 290;
const Size meadowWarmGlowRadii = Size(840, 217.6);
const double meadowOverlayCentreY = 300;
const Size meadowOverlayRadii = Size(560, 460);

class _Rgb {
  const _Rgb(this.red, this.green, this.blue);

  _Rgb.of(Color colour)
    : red = colour.r * 255,
      green = colour.g * 255,
      blue = colour.b * 255;

  final double red;
  final double green;
  final double blue;

  _Rgb mix(_Rgb other, double k) => _Rgb(
    red + (other.red - red) * k,
    green + (other.green - green) * k,
    blue + (other.blue - blue) * k,
  );

  Color colour([double alpha = 1]) =>
      Color.fromRGBO(_channel(red), _channel(green), _channel(blue), alpha);
}

int _channel(double value) => value.clamp(0.0, 255.0).round();

double _unit(double value) => value.clamp(0.0, 1.0);

double _worldY(double altitude) => 292 - (altitude / 60).clamp(-1.3, 1.0) * 250;

const _Rgb _white = _Rgb(255, 255, 255);
const _Rgb _nightCloudTop = _Rgb(34, 40, 70);
const _Rgb _nightCloudBottom = _Rgb(28, 34, 62);
const _Rgb _nightOverlay = _Rgb(18, 24, 58);
const _Rgb _warmOverlay = _Rgb(236, 150, 96);
const _Rgb _warmGlow = _Rgb(250, 176, 120);
const _Rgb _moonLight = _Rgb(206, 214, 242);
const _Rgb _moonGlow = _Rgb(226, 232, 255);
const _Rgb _moonGlint = _Rgb(236, 240, 255);
const Color _shade = Color.fromRGBO(66, 62, 118, 1);
const Color _nightCaption = Color.fromRGBO(236, 230, 214, 0.85);
const Color _dayCaption = Color.fromRGBO(60, 48, 36, 0.72);

class MeadowPalette {
  const MeadowPalette({
    required this.skyTop,
    required this.skyMiddle,
    required this.skyHorizon,
    required this.warmGlowColour,
    required this.warmGlowCentre,
    required this.sunColour,
    required this.sunPosition,
    required this.moonPosition,
    required this.moonOpacity,
    required this.moonGlowColour,
    required this.moonShadeOffset,
    required this.moonShadeColour,
    required this.starsOpacity,
    required this.milkyOpacity,
    required this.raysOpacity,
    required this.raysGlowAlpha,
    required this.m0,
    required this.m0b,
    required this.m1t,
    required this.m1b,
    required this.m1d,
    required this.r1,
    required this.r2,
    required this.rS,
    required this.rL,
    required this.scr,
    required this.fo1,
    required this.fo2,
    required this.fo3,
    required this.wf,
    required this.wfHi,
    required this.snow,
    required this.lit,
    required this.shade,
    required this.litL,
    required this.litR,
    required this.shL,
    required this.shR,
    required this.fog,
    required this.fogV,
    required this.fogL,
    required this.fogP,
    required this.hz,
    required this.lk1,
    required this.lk2,
    required this.lkHi,
    required this.st2,
    required this.wDeep,
    required this.wSh,
    required this.flowC,
    required this.flowO,
    required this.glintC,
    required this.glintO,
    required this.glintX,
    required this.cloudTop,
    required this.cloudBottom,
    required this.overlayColour,
    required this.overlayAlpha,
    required this.overlayCentreAlpha,
    required this.overlayCentre,
    required this.dayLife,
    required this.fireflies,
    required this.captionColour,
  });

  factory MeadowPalette.from({
    required SkyScene sky,
    required bool morning,
    required double heavyShare,
  }) {
    final _Rgb top = _Rgb.of(sky.gradient.top);
    final _Rgb middle = _Rgb.of(sky.gradient.middle);
    final _Rgb horizon = _Rgb.of(sky.gradient.horizon);
    final _Rgb sun = _Rgb.of(sky.sunColour);
    final double a = sky.sunAltitude;
    final double night = sky.night;
    final double warm = sky.warm;
    final double fraction = sky.moonFraction;
    final double sunX = sky.sunX * meadowWorldWidth;
    final double moonX = sky.moonX * meadowWorldWidth;
    final double up = _unit((a + 1) / 5);
    final bool sunlit = up > 0.02;

    final _Rgb m0 = const _Rgb(150, 164, 200).mix(horizon, 0.5);
    final _Rgb m1 = const _Rgb(124, 134, 182).mix(horizon, 0.4);
    final _Rgb lakeSky = middle.mix(horizon, 0.6);
    final _Rgb dayCloudTop = const _Rgb(252, 249, 242).mix(horizon, 0.25);

    final double light;
    final double side;
    final _Rgb lit;
    if (sunlit) {
      light = up * (0.3 + 0.6 * warm) * (1 - 0.45 * _unit(a / 50));
      side = (sunX - 700) / 700;
      lit = const _Rgb(255, 238, 204).mix(sun, 0.55);
    } else {
      light = sky.moonUp ? night * fraction * 0.32 : 0;
      side = (moonX - 700) / 700;
      lit = _moonLight;
    }
    final double litL = light * (0.5 - side).clamp(0.06, 1.0);
    final double litR = light * (0.5 + side).clamp(0.06, 1.0);

    final double dawn = morning ? _unit(1 - (a - 1).abs() / 10) : 0;
    final double fogBase = 0.3 + 0.6 * heavyShare;
    final double moonlight = sky.moonUp ? night * (0.3 + 0.7 * fraction) : 0;
    final double glintO = sunlit ? up * (0.35 + 0.65 * warm) : moonlight * 0.9;

    final double nightAlpha = night * 0.66;
    final double warmAlpha = warm * up * 0.16;
    final bool nightOverlay = nightAlpha > warmAlpha;
    final double overlayAlpha = math.max(nightAlpha, warmAlpha);

    final double stars = _unit((-a - 4) / 8);
    final double rays =
        _unit((a - 0.5) / 4) *
        (0.08 + 0.34 * warm) *
        (0.5 + 0.7 * _unit(fogBase)) *
        (1 - 0.7 * _unit(a / 40));

    return MeadowPalette(
      skyTop: top.colour(),
      skyMiddle: middle.colour(),
      skyHorizon: horizon.colour(),
      warmGlowColour: _warmGlow.colour(0.55 * warm),
      warmGlowCentre: Offset(sunX, meadowWarmGlowY),
      sunColour: sun.colour(),
      sunPosition: Offset(sunX, _worldY(a)),
      moonPosition: Offset(moonX, _worldY(sky.moonAltitude)),
      moonOpacity: 0.4 + 0.6 * night,
      moonGlowColour: _moonGlow.colour(
        0.12 + 0.5 * night * (0.4 + 0.6 * fraction),
      ),
      moonShadeOffset: (sky.moonPhase < 0.5 ? -1 : 1) * fraction,
      moonShadeColour: top.colour(0.94),
      starsOpacity: stars,
      milkyOpacity: stars * 0.8,
      raysOpacity: rays < 0.005 ? 0 : rays,
      raysGlowAlpha: 0.32 * warm + 0.06,
      m0: m0.colour(),
      m0b: m0.mix(horizon, 0.5).colour(),
      m1t: m1.colour(),
      m1b: m1.mix(horizon, 0.35).colour(),
      m1d: m1.mix(const _Rgb(44, 46, 84), 0.4).colour(),
      r1: const _Rgb(182, 140, 118).mix(horizon, 0.14).colour(),
      r2: const _Rgb(146, 112, 100).mix(horizon, 0.1).colour(),
      rS: const _Rgb(104, 78, 78).mix(horizon, 0.08).colour(),
      rL: const _Rgb(214, 184, 156).mix(horizon, 0.1).colour(),
      scr: const _Rgb(206, 188, 168).mix(horizon, 0.12).colour(),
      fo1: const _Rgb(40, 72, 62).mix(horizon, 0.12).colour(),
      fo2: const _Rgb(58, 94, 74).mix(horizon, 0.12).colour(),
      fo3: const _Rgb(28, 52, 48).mix(horizon, 0.1).colour(),
      wf: const _Rgb(226, 242, 240).mix(horizon, 0.2).colour(),
      wfHi: _white.mix(horizon, 0.1).colour(),
      snow: const _Rgb(240, 244, 250).mix(horizon, 0.22).colour(),
      lit: lit.colour(),
      shade: _shade,
      litL: litL,
      litR: litR,
      shL: litR * 0.55,
      shR: litL * 0.55,
      fog: const _Rgb(246, 242, 232).mix(horizon, 0.4).colour(0.92),
      fogV: _unit(fogBase * (0.5 + 0.9 * dawn + 0.35 * night)),
      fogL: _unit(fogBase * (0.2 + 1.1 * dawn + 0.4 * night)),
      fogP: _unit((0.4 + 0.45 * heavyShare) * (0.6 + 0.7 * dawn + 0.5 * night)),
      hz: const _Rgb(234, 232, 216).mix(horizon, 0.35).colour(0.9),
      lk1: const _Rgb(118, 192, 190).mix(lakeSky, 0.32).colour(),
      lk2: const _Rgb(62, 150, 156).mix(top, 0.12).colour(),
      lkHi: horizon.mix(_white, 0.45).colour(),
      st2: const _Rgb(54, 136, 146).mix(top, 0.14).colour(),
      wDeep: const _Rgb(28, 88, 104).mix(top, 0.1).colour(),
      wSh: const _Rgb(158, 208, 194).mix(horizon, 0.22).colour(),
      flowC: horizon.mix(_white, 0.5).colour(),
      flowO: 0.2 + 0.45 * (1 - night),
      glintC: sunlit
          ? const _Rgb(255, 246, 214).mix(sun, 0.4).colour()
          : _moonGlint.colour(),
      glintO: glintO,
      glintX: sunlit ? sunX : moonX,
      cloudTop: dayCloudTop.mix(_nightCloudTop, night * 0.86).colour(),
      cloudBottom: const _Rgb(238, 234, 232)
          .mix(horizon, 0.35)
          .mix(sun, warm * 0.6)
          .mix(_nightCloudBottom, night * 0.86)
          .colour(),
      overlayColour: (nightOverlay ? _nightOverlay : _warmOverlay).colour(),
      overlayAlpha: overlayAlpha,
      overlayCentreAlpha: nightOverlay
          ? math.max(0.0, nightAlpha - moonlight * 0.34)
          : overlayAlpha,
      overlayCentre: Offset(moonX, meadowOverlayCentreY),
      dayLife: 1 - _unit(night / 0.6),
      fireflies: _unit((night - 0.45) / 0.45),
      captionColour: night > 0.55 ? _nightCaption : _dayCaption,
    );
  }

  final Color skyTop;
  final Color skyMiddle;
  final Color skyHorizon;
  final Color warmGlowColour;
  final Offset warmGlowCentre;
  final Color sunColour;
  final Offset sunPosition;
  final Offset moonPosition;
  final double moonOpacity;
  final Color moonGlowColour;
  final double moonShadeOffset;
  final Color moonShadeColour;
  final double starsOpacity;
  final double milkyOpacity;
  final double raysOpacity;
  final double raysGlowAlpha;
  final Color m0;
  final Color m0b;
  final Color m1t;
  final Color m1b;
  final Color m1d;
  final Color r1;
  final Color r2;
  final Color rS;
  final Color rL;
  final Color scr;
  final Color fo1;
  final Color fo2;
  final Color fo3;
  final Color wf;
  final Color wfHi;
  final Color snow;
  final Color lit;
  final Color shade;
  final double litL;
  final double litR;
  final double shL;
  final double shR;
  final Color fog;
  final double fogV;
  final double fogL;
  final double fogP;
  final Color hz;
  final Color lk1;
  final Color lk2;
  final Color lkHi;
  final Color st2;
  final Color wDeep;
  final Color wSh;
  final Color flowC;
  final double flowO;
  final Color glintC;
  final double glintO;
  final double glintX;
  final Color cloudTop;
  final Color cloudBottom;
  final Color overlayColour;
  final double overlayAlpha;
  final double overlayCentreAlpha;
  final Offset overlayCentre;
  final double dayLife;
  final double fireflies;
  final Color captionColour;

  List<Object> get _values => <Object>[
    skyTop,
    skyMiddle,
    skyHorizon,
    warmGlowColour,
    warmGlowCentre,
    sunColour,
    sunPosition,
    moonPosition,
    moonOpacity,
    moonGlowColour,
    moonShadeOffset,
    moonShadeColour,
    starsOpacity,
    milkyOpacity,
    raysOpacity,
    raysGlowAlpha,
    m0,
    m0b,
    m1t,
    m1b,
    m1d,
    r1,
    r2,
    rS,
    rL,
    scr,
    fo1,
    fo2,
    fo3,
    wf,
    wfHi,
    snow,
    lit,
    shade,
    litL,
    litR,
    shL,
    shR,
    fog,
    fogV,
    fogL,
    fogP,
    hz,
    lk1,
    lk2,
    lkHi,
    st2,
    wDeep,
    wSh,
    flowC,
    flowO,
    glintC,
    glintO,
    glintX,
    cloudTop,
    cloudBottom,
    overlayColour,
    overlayAlpha,
    overlayCentreAlpha,
    overlayCentre,
    dayLife,
    fireflies,
    captionColour,
  ];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeadowPalette &&
          runtimeType == other.runtimeType &&
          listEquals(_values, other._values);

  @override
  int get hashCode => Object.hashAll(_values);
}
