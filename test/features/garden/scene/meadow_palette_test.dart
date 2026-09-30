import 'dart:math' as math;
import 'dart:ui';

import 'package:field_notes/features/garden/scene/meadow_palette.dart';
import 'package:field_notes/features/garden/sky/sky_scene.dart';
import 'package:flutter_test/flutter_test.dart';

Color _rgb(List<num> channels, [double alpha = 1]) => Color.from(
  alpha: alpha,
  red: channels[0] / 255,
  green: channels[1] / 255,
  blue: channels[2] / 255,
);

SkyScene _sky({
  required double a,
  required double sunX,
  required double moonX,
  required bool moonUp,
  required double moonAltitude,
  required double fraction,
  required double phase,
  required List<int> top,
  required List<int> middle,
  required List<int> horizon,
}) {
  final double night = ((2 - a) / 12).clamp(0.0, 1.0);
  final double warm = math.max(0.0, 1 - (a - 2).abs() / 9);
  final double low = (1 - a / 14).clamp(0.0, 1.0);
  final List<double> sun = <double>[
    244 + (238 - 244) * low,
    201 + (124 - 201) * low,
    96 + (74 - 96) * low,
  ];
  return SkyScene(
    sunAltitude: a,
    moonAltitude: moonAltitude,
    gradient: SkyGradient(
      top: _rgb(top),
      middle: _rgb(middle),
      horizon: _rgb(horizon),
    ),
    night: night,
    warm: warm,
    low: low,
    sunX: sunX / 1400,
    sunY: (31 - (a / 62).clamp(-1.3, 1.0) * 23) / 100,
    sunColour: _rgb(sun),
    warmGlow: _rgb(<int>[250, 176, 120], 0.55 * warm),
    moonX: moonX / 1400,
    moonY: (31 - (moonAltitude / 62).clamp(-1.3, 1.0) * 23) / 100,
    moonUp: moonUp,
    moonFraction: fraction,
    moonPhase: phase,
    moonOpacity: 0.4 + 0.6 * night,
    moonGlowAlpha: 0.12 + 0.5 * night * (0.4 + 0.6 * fraction),
    moonShadeOffset: (phase < 0.5 ? -1 : 1) * fraction,
    moonPool: _rgb(<int>[22, 28, 60], 0.8 * night),
    nightEdge: _rgb(<int>[20, 26, 58], 0.82 * night),
    warmTint: warm > 0.02 ? _rgb(<int>[236, 150, 104], 0.3 * warm) : null,
    starsOpacity: ((-a - 4) / 8).clamp(0.0, 1.0),
    hazeOpacity: 1 - 0.85 * night,
    firefliesOpacity: ((night - 0.4) / 0.6).clamp(0.0, 1.0),
    dayLifeOpacity: 1 - (night / 0.7).clamp(0.0, 1.0),
    captionColour: night > 0.55
        ? const Color.fromRGBO(236, 230, 214, 0.82)
        : const Color.fromRGBO(60, 48, 36, 0.72),
    phaseName: 'waxing gibbous',
  );
}

void _expectRgb(Color colour, List<int> expected, [double? alpha]) {
  expect(colour.r * 255, closeTo(expected[0], 1));
  expect(colour.g * 255, closeTo(expected[1], 1));
  expect(colour.b * 255, closeTo(expected[2], 1));
  if (alpha != null) {
    expect(colour.a, closeTo(alpha, 0.002));
  }
}

void main() {
  test('the palette matches the prototype at noon, dawn and midnight', () {
    final MeadowPalette noon = MeadowPalette.from(
      sky: _sky(
        a: 40,
        sunX: 700,
        moonX: 300,
        moonUp: false,
        moonAltitude: -20,
        fraction: 0.5,
        phase: 0.25,
        top: <int>[190, 210, 222],
        middle: <int>[224, 228, 218],
        horizon: <int>[238, 232, 210],
      ),
      morning: false,
      heavyShare: 0.3,
    );
    _expectRgb(noon.m0, <int>[194, 198, 205]);
    _expectRgb(noon.m1t, <int>[170, 173, 193]);
    _expectRgb(noon.r1, <int>[190, 153, 131]);
    _expectRgb(noon.fo1, <int>[64, 91, 80]);
    _expectRgb(noon.snow, <int>[240, 241, 241]);
    _expectRgb(noon.lit, <int>[249, 218, 145]);
    expect(noon.litL, closeTo(0.096, 0.002));
    expect(noon.litR, closeTo(0.096, 0.002));
    _expectRgb(noon.fog, <int>[243, 238, 223], 0.92);
    expect(noon.fogV, closeTo(0.240, 0.002));
    expect(noon.fogL, closeTo(0.096, 0.002));
    expect(noon.fogP, closeTo(0.321, 0.002));
    _expectRgb(noon.lk1, <int>[155, 204, 197]);
    _expectRgb(noon.lk2, <int>[77, 157, 164]);
    _expectRgb(noon.st2, <int>[73, 146, 157]);
    expect(noon.glintO, closeTo(0.350, 0.002));
    expect(noon.glintX, closeTo(700, 0.001));
    _expectRgb(noon.cloudTop, <int>[249, 245, 234]);
    _expectRgb(noon.cloudBottom, <int>[238, 233, 224]);
    expect(noon.overlayAlpha, closeTo(0, 0.002));
    expect(noon.starsOpacity, closeTo(0, 0.002));
    expect(noon.milkyOpacity, closeTo(0, 0.002));
    expect(noon.raysOpacity, closeTo(0.020, 0.002));
    expect(noon.dayLife, closeTo(1, 0.002));
    expect(noon.fireflies, closeTo(0, 0.002));
    expect(noon.sunPosition.dx, closeTo(700, 0.001));
    expect(noon.sunPosition.dy, closeTo(292 - 40 / 60 * 250, 0.001));
    _expectRgb(noon.captionColour, <int>[60, 48, 36], 0.72);

    final MeadowPalette dawn = MeadowPalette.from(
      sky: _sky(
        a: 1,
        sunX: 500,
        moonX: 900,
        moonUp: true,
        moonAltitude: 30,
        fraction: 0.4,
        phase: 0.8,
        top: <int>[129, 140, 175],
        middle: <int>[215, 179, 158],
        horizon: <int>[240, 177, 132],
      ),
      morning: true,
      heavyShare: 0.5,
    );
    _expectRgb(dawn.m0, <int>[195, 170, 166]);
    _expectRgb(dawn.m1t, <int>[170, 151, 162]);
    _expectRgb(dawn.r1, <int>[190, 145, 120]);
    _expectRgb(dawn.fo1, <int>[64, 85, 70]);
    _expectRgb(dawn.snow, <int>[240, 229, 224]);
    _expectRgb(dawn.lit, <int>[246, 178, 133]);
    expect(dawn.litL, closeTo(0.260, 0.002));
    expect(dawn.litR, closeTo(0.071, 0.002));
    _expectRgb(dawn.fog, <int>[243, 216, 192], 0.92);
    expect(dawn.fogV, closeTo(0.857, 0.002));
    expect(dawn.fogL, closeTo(0.800, 0.002));
    expect(dawn.fogP, closeTo(0.839, 0.002));
    _expectRgb(dawn.lk1, <int>[154, 187, 175]);
    _expectRgb(dawn.lk2, <int>[70, 149, 158]);
    _expectRgb(dawn.st2, <int>[65, 137, 150]);
    expect(dawn.glintO, closeTo(0.371, 0.002));
    expect(dawn.glintX, closeTo(500, 0.001));
    _expectRgb(dawn.cloudTop, <int>[233, 217, 204]);
    _expectRgb(dawn.cloudBottom, <int>[223, 159, 127]);
    _expectRgb(dawn.overlayColour, <int>[236, 150, 96]);
    expect(dawn.overlayAlpha, closeTo(0.057, 0.002));
    expect(dawn.overlayCentreAlpha, closeTo(0.057, 0.002));
    expect(dawn.starsOpacity, closeTo(0, 0.002));
    expect(dawn.raysOpacity, closeTo(0.043, 0.002));
    expect(dawn.dayLife, closeTo(0.861, 0.002));
    expect(dawn.fireflies, closeTo(0, 0.002));
    expect(dawn.moonPosition.dx, closeTo(900, 0.001));
    expect(dawn.moonPosition.dy, closeTo(292 - 30 / 60 * 250, 0.001));
    expect(dawn.moonShadeOffset, closeTo(0.4, 0.002));
    _expectRgb(dawn.captionColour, <int>[60, 48, 36], 0.72);

    final MeadowPalette midnight = MeadowPalette.from(
      sky: _sky(
        a: -30,
        sunX: 1300,
        moonX: 650,
        moonUp: true,
        moonAltitude: 45,
        fraction: 0.95,
        phase: 0.45,
        top: <int>[12, 16, 34],
        middle: <int>[22, 28, 56],
        horizon: <int>[38, 44, 76],
      ),
      morning: false,
      heavyShare: 0.2,
    );
    _expectRgb(midnight.m0, <int>[94, 104, 138]);
    _expectRgb(midnight.m1t, <int>[90, 98, 140]);
    _expectRgb(midnight.r1, <int>[162, 127, 112]);
    _expectRgb(midnight.fo1, <int>[40, 69, 64]);
    _expectRgb(midnight.snow, <int>[196, 200, 212]);
    _expectRgb(midnight.lit, <int>[206, 214, 242]);
    expect(midnight.litL, closeTo(0.174, 0.002));
    expect(midnight.litR, closeTo(0.130, 0.002));
    _expectRgb(midnight.fog, <int>[163, 163, 170], 0.92);
    expect(midnight.fogV, closeTo(0.357, 0.002));
    expect(midnight.fogL, closeTo(0.252, 0.002));
    expect(midnight.fogP, closeTo(0.539, 0.002));
    _expectRgb(midnight.lk1, <int>[90, 143, 151]);
    _expectRgb(midnight.lk2, <int>[56, 134, 141]);
    _expectRgb(midnight.st2, <int>[48, 119, 130]);
    expect(midnight.glintO, closeTo(0.868, 0.002));
    expect(midnight.glintX, closeTo(650, 0.001));
    _expectRgb(midnight.cloudTop, <int>[57, 62, 88]);
    _expectRgb(midnight.cloudBottom, <int>[48, 53, 78]);
    _expectRgb(midnight.overlayColour, <int>[18, 24, 58]);
    expect(midnight.overlayAlpha, closeTo(0.660, 0.002));
    expect(midnight.overlayCentreAlpha, closeTo(0.332, 0.002));
    expect(midnight.overlayCentre.dx, closeTo(650, 0.001));
    expect(midnight.starsOpacity, closeTo(1, 0.002));
    expect(midnight.milkyOpacity, closeTo(0.8, 0.002));
    expect(midnight.raysOpacity, closeTo(0, 0.002));
    expect(midnight.dayLife, closeTo(0, 0.002));
    expect(midnight.fireflies, closeTo(1, 0.002));
    expect(midnight.sunPosition.dy, closeTo(292 + 0.5 * 250, 0.001));
    expect(midnight.moonShadeOffset, closeTo(-0.95, 0.002));
    _expectRgb(midnight.moonShadeColour, <int>[12, 16, 34], 0.94);
    _expectRgb(midnight.captionColour, <int>[236, 230, 214], 0.85);

    expect(
      MeadowPalette.from(
        sky: _sky(
          a: -30,
          sunX: 1300,
          moonX: 650,
          moonUp: true,
          moonAltitude: 45,
          fraction: 0.95,
          phase: 0.45,
          top: <int>[12, 16, 34],
          middle: <int>[22, 28, 56],
          horizon: <int>[38, 44, 76],
        ),
        morning: false,
        heavyShare: 0.2,
      ),
      midnight,
    );
    expect(midnight == noon, isFalse);
  });
}
