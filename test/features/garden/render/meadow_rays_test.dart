import 'dart:ui';

import 'package:field_notes/features/garden/render/meadow_rays.dart';
import 'package:field_notes/features/garden/scene/meadow_palette.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/meadow_pixels.dart';

MeadowPalette _withSunAt(MeadowPalette palette, Offset sunPosition) =>
    MeadowPalette(
      skyTop: palette.skyTop,
      skyMiddle: palette.skyMiddle,
      skyHorizon: palette.skyHorizon,
      warmGlowColour: palette.warmGlowColour,
      warmGlowCentre: palette.warmGlowCentre,
      sunColour: palette.sunColour,
      sunPosition: sunPosition,
      moonPosition: palette.moonPosition,
      moonOpacity: palette.moonOpacity,
      moonGlowColour: palette.moonGlowColour,
      moonShadeOffset: palette.moonShadeOffset,
      moonShadeColour: palette.moonShadeColour,
      starsOpacity: palette.starsOpacity,
      milkyOpacity: palette.milkyOpacity,
      raysOpacity: palette.raysOpacity,
      raysGlowAlpha: palette.raysGlowAlpha,
      m0: palette.m0,
      m0b: palette.m0b,
      m1t: palette.m1t,
      m1b: palette.m1b,
      m1d: palette.m1d,
      r1: palette.r1,
      r2: palette.r2,
      rS: palette.rS,
      rL: palette.rL,
      scr: palette.scr,
      fo1: palette.fo1,
      fo2: palette.fo2,
      fo3: palette.fo3,
      wf: palette.wf,
      wfHi: palette.wfHi,
      snow: palette.snow,
      lit: palette.lit,
      shade: palette.shade,
      litL: palette.litL,
      litR: palette.litR,
      shL: palette.shL,
      shR: palette.shR,
      fog: palette.fog,
      fogV: palette.fogV,
      fogL: palette.fogL,
      fogP: palette.fogP,
      hz: palette.hz,
      lk1: palette.lk1,
      lk2: palette.lk2,
      lkHi: palette.lkHi,
      st2: palette.st2,
      wDeep: palette.wDeep,
      wSh: palette.wSh,
      flowC: palette.flowC,
      flowO: palette.flowO,
      glintC: palette.glintC,
      glintO: palette.glintO,
      glintX: palette.glintX,
      cloudTop: palette.cloudTop,
      cloudBottom: palette.cloudBottom,
      overlayColour: palette.overlayColour,
      overlayAlpha: palette.overlayAlpha,
      overlayCentreAlpha: palette.overlayCentreAlpha,
      overlayCentre: palette.overlayCentre,
      dayLife: palette.dayLife,
      fireflies: palette.fireflies,
      captionColour: palette.captionColour,
    );

void main() {
  test("the rays are baked again only when the sun's colours change", () {
    final Map<String, MeadowPalette> palettes = meadowPixelsPalettes(
      meadowPixelsLeapYear(),
    );
    final MeadowPalette noon = palettes['noon']!;
    final MeadowPalette dusk = palettes['dusk']!;
    final int side = (2 * meadowRaysReach * meadowRaysScale).ceil();

    final MeadowRays rays = MeadowRays(noon);
    addTearDown(rays.dispose);
    final Image baked = rays.image;
    expect(baked.width, side);
    expect(baked.height, side);
    expect(rays.debugGeometryRecordings, 2);

    final MeadowPalette moved = _withSunAt(
      noon,
      noon.sunPosition + const Offset(40, 0),
    );
    expect(moved, isNot(noon));
    expect(moved.sunColour, noon.sunColour);
    expect(moved.raysGlowAlpha, noon.raysGlowAlpha);
    rays.recolour(moved);
    expect(baked.debugDisposed, isFalse);
    expect(rays.image, same(baked));

    expect(dusk.sunColour, isNot(noon.sunColour));
    rays.recolour(dusk);
    expect(rays.image, isNot(same(baked)));
    expect(baked.debugDisposed, isTrue);
    expect(rays.image.debugDisposed, isFalse);
    expect(rays.debugGeometryRecordings, 2);
  });
}
