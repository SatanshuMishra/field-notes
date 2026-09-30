import 'dart:math' as math;
import 'dart:ui';

import 'package:field_notes/features/garden/sky/sky_scene.dart';
import 'package:flutter_test/flutter_test.dart';

const double edmontonLatitude = 53.55;
const double edmontonLongitude = -113.4667;

(int, int, int) rgb(Color colour) => (
  (colour.r * 255).round(),
  (colour.g * 255).round(),
  (colour.b * 255).round(),
);

SkyScene edmontonAt(String iso) =>
    skySceneAt(DateTime.parse(iso), edmontonLatitude, edmontonLongitude);

void main() {
  test('sky colours interpolate the altitude keyframes', () {
    final SkyGradient belowFirst = skyGradientAt(-20);
    expect(rgb(belowFirst.top), (12, 16, 34));
    expect(rgb(belowFirst.middle), (22, 28, 56));
    expect(rgb(belowFirst.horizon), (38, 44, 76));

    expect(skyGradientAt(-14), belowFirst);

    final SkyGradient aboveLast = skyGradientAt(30);
    expect(rgb(aboveLast.top), (190, 210, 222));
    expect(rgb(aboveLast.middle), (224, 228, 218));
    expect(rgb(aboveLast.horizon), (238, 232, 210));

    expect(skyGradientAt(20), aboveLast);

    final SkyGradient midway = skyGradientAt(6);
    expect(rgb(midway.top), (177, 187, 204));
    expect(rgb(midway.middle), (233, 211, 185));
    expect(rgb(midway.horizon), (242, 205, 165));
    expect(midway.top.a, 1);
  });

  test("the day sky is the prototype's bluer sky", () {
    final SkyGradient low = skyGradientAt(10);
    expect(rgb(low.top), (204, 214, 216));
    expect(rgb(low.middle), (232, 226, 208));
    expect(rgb(low.horizon), (240, 226, 196));

    final SkyGradient high = skyGradientAt(20);
    expect(rgb(high.top), (190, 210, 222));
    expect(rgb(high.middle), (224, 228, 218));
    expect(rgb(high.horizon), (238, 232, 210));

    final SkyGradient between = skyGradientAt(15);
    expect(rgb(between.top), (197, 212, 219));
    expect(rgb(between.middle), (228, 227, 213));
    expect(rgb(between.horizon), (239, 229, 203));

    final SkyGradient dawn = skyGradientAt(2);
    expect(rgb(dawn.top), (150, 160, 192));
    expect(rgb(dawn.middle), (234, 196, 162));
    expect(rgb(dawn.horizon), (244, 184, 134));

    final SkyGradient twilight = skyGradientAt(-3);
    expect(rgb(twilight.top), (46, 58, 106));
    expect(rgb(twilight.middle), (138, 110, 142));
    expect(rgb(twilight.horizon), (222, 148, 122));

    expect(rgb(edmontonAt('2026-09-28T18:00:00Z').skyTop), (190, 210, 222));
  });

  test('night, warm and low weights follow the sun', () {
    expect(skyNightWeight(-10), 1);
    expect(skyNightWeight(2), 0);
    expect(skyNightWeight(-4), closeTo(0.5, 0.0005));
    expect(skyWarmWeight(2), 1);
    expect(skyWarmWeight(11), 0);
    expect(skyWarmWeight(-7), 0);
    expect(skyWarmWeight(6.5), closeTo(0.5, 0.0005));
    expect(skyLowWeight(14), 0);
    expect(skyLowWeight(0), 1);
    expect(skyLowWeight(7), closeTo(0.5, 0.0005));
  });

  test(
    'sun and moon screen positions follow azimuth and altitude and mirror in the south',
    () {
      expect(skyScreenX(0, edmontonLatitude), closeTo(0.5, 0.0001));
      expect(
        skyScreenX(-math.pi / 2, edmontonLatitude),
        closeTo(0.1371, 0.0001),
      );
      expect(
        skyScreenX(math.pi / 2, edmontonLatitude),
        closeTo(0.8629, 0.0001),
      );
      expect(skyScreenX(math.pi, edmontonLatitude), closeTo(0.95, 0.0001));
      expect(skyScreenX(math.pi, -33.8667), closeTo(0.5, 0.0001));
      expect(skyScreenX(math.pi / 2, -33.8667), closeTo(0.1371, 0.0001));
      expect(skyScreenY(0), closeTo(0.31, 0.0001));
      expect(skyScreenY(62), closeTo(0.08, 0.0001));
      expect(skyScreenY(90), closeTo(0.08, 0.0001));
      expect(skyScreenY(-90), closeTo(0.609, 0.0001));

      final SkyScene sydney = skySceneAt(
        DateTime.parse('2026-12-01T02:00:00Z'),
        -33.8667,
        151.2167,
      );
      expect(sydney.sunX, closeTo(0.4302, 0.0001));
      expect(sydney.sunY, closeTo(0.08, 0.0001));
    },
  );

  test('Edmonton noon, dusk and midnight match the design fixtures', () {
    final SkyScene noon = edmontonAt('2026-09-28T18:00:00Z');
    expect(noon.sunX, closeTo(0.3994, 0.0001));
    expect(noon.sunY, closeTo(0.1931, 0.0001));
    expect(noon.moonX, closeTo(0.95, 0.0001));
    expect(noon.moonY, closeTo(0.3491, 0.0001));
    expect(noon.moonUp, isFalse);
    expect(rgb(noon.skyTop), (190, 210, 222));
    expect(noon.night, closeTo(0, 0.0005));
    expect(noon.warm, closeTo(0, 0.0005));
    expect(noon.starsOpacity, closeTo(0, 0.0005));
    expect(noon.firefliesOpacity, closeTo(0, 0.0005));
    expect(noon.dayLifeOpacity, closeTo(1, 0.0005));
    expect(noon.warmTint, isNull);
    expect(noon.captionColour, const Color.fromRGBO(60, 48, 36, 0.72));
    expect(noon.phaseName, 'waning gibbous');

    final SkyScene dusk = edmontonAt('2026-09-29T01:00:00Z');
    expect(dusk.sunX, closeTo(0.8376, 0.0001));
    expect(dusk.sunY, closeTo(0.3036, 0.0001));
    expect(dusk.moonX, closeTo(0.05, 0.0001));
    expect(dusk.moonY, closeTo(0.3222, 0.0001));
    expect(dusk.moonUp, isFalse);
    expect(rgb(dusk.skyTop), (144, 154, 187));
    expect(rgb(dusk.skyMiddle), (229, 191, 161));
    expect(rgb(dusk.skyHorizon), (243, 182, 133));
    expect(dusk.night, closeTo(0.0238, 0.0005));
    expect(dusk.warm, closeTo(0.9683, 0.0005));
    expect(rgb(dusk.sunColour), (239, 133, 77));
    expect(dusk.dayLifeOpacity, closeTo(0.9661, 0.0005));
    expect(dusk.hazeOpacity, closeTo(0.9798, 0.0005));
    expect(dusk.warmGlowX, dusk.sunX);
    expect(dusk.warmGlowY, 0.33);
    expect(dusk.warmGlowAlpha, closeTo(0.55 * dusk.warm, 0.0005));
    expect(rgb(dusk.warmTint!), (236, 150, 104));
    expect(dusk.warmTint!.a, closeTo(0.3 * dusk.warm, 0.0005));
    expect(rgb(dusk.moonPool), (22, 28, 60));
    expect(dusk.captionColour, const Color.fromRGBO(60, 48, 36, 0.72));

    final SkyScene midnight = edmontonAt('2026-09-29T06:00:00Z');
    expect(midnight.sunX, closeTo(0.95, 0.0001));
    expect(midnight.sunY, closeTo(0.4436, 0.0001));
    expect(midnight.moonX, closeTo(0.2249, 0.0001));
    expect(midnight.moonY, closeTo(0.1678, 0.0001));
    expect(midnight.moonUp, isTrue);
    expect(rgb(midnight.skyTop), (12, 16, 34));
    expect(midnight.night, closeTo(1, 0.0005));
    expect(midnight.warm, closeTo(0, 0.0005));
    expect(midnight.starsOpacity, closeTo(1, 0.0005));
    expect(midnight.firefliesOpacity, closeTo(1, 0.0005));
    expect(midnight.dayLifeOpacity, closeTo(0, 0.0005));
    expect(rgb(midnight.moonPool), (172, 184, 230));
    expect(midnight.moonPoolAlpha, closeTo(0.8, 0.0005));
    expect(rgb(midnight.nightEdge), (20, 26, 58));
    expect(midnight.nightEdgeAlpha, closeTo(0.82, 0.0005));
    expect(midnight.warmTint, isNull);
    expect(midnight.hazeOpacity, closeTo(0.15, 0.0005));
    expect(midnight.moonOpacity, closeTo(1, 0.0005));
    expect(
      midnight.moonGlowAlpha,
      closeTo(0.12 + 0.5 * (0.4 + 0.6 * midnight.moonFraction), 0.0005),
    );
    expect(midnight.moonShadeOffset, closeTo(midnight.moonFraction, 0.0005));
    expect(midnight.captionColour, const Color.fromRGBO(236, 230, 214, 0.82));
    expect(midnight.phaseName, 'waning gibbous');
  });
}
