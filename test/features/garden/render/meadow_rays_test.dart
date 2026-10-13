import 'dart:typed_data';
import 'dart:ui';

import 'package:field_notes/features/garden/render/meadow_rays.dart';
import 'package:field_notes/features/garden/scene/meadow_pacer.dart';
import 'package:field_notes/features/garden/scene/meadow_palette.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/image_count.dart';
import '../support/meadow_pixels.dart';
import '../support/meadow_stage_harness.dart';

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
  final Map<String, MeadowPalette> palettes = meadowPixelsPalettes(
    meadowPixelsLeapYear(),
  );
  final MeadowPalette noon = palettes['noon']!;
  final MeadowPalette dusk = palettes['dusk']!;
  final int side = (2 * meadowRaysReach * meadowRaysScale).ceil();

  ImageCount countImages() {
    final ImageCount count = ImageCount()..start();
    addTearDown(count.stop);
    return count;
  }

  Future<Uint8List> bytesOf(Image image) async =>
      (await image.toByteData(format: ImageByteFormat.rawRgba))!.buffer
          .asUint8List();

  test('the rays count every image they render', () {
    final MeadowPacer pacer = installPacer(MeadowPacer());
    final ImageCount count = countImages();
    final MeadowRays rays = MeadowRays(noon)..buildAll();
    addTearDown(rays.dispose);
    expect(count.created, 3);
    expect(pacer.debugSnapshots, count.created);

    rays
      ..recolour(dusk)
      ..buildAll();
    expect(count.created, 4);
    expect(pacer.debugSnapshots, count.created);
  });

  test('the rays build in three steps of one image each', () {
    installPacer(MeadowPacer());
    final ImageCount count = countImages();
    final MeadowRays rays = MeadowRays(noon);
    addTearDown(rays.dispose);
    expect(count.created, 0);
    expect(rays.isReady, isFalse);

    for (int i = 0; i < 3; i++) {
      final int before = count.created;
      rays.step();
      expect(count.created - before, 1, reason: 'step ${i + 1}');
      expect(rays.isReady, i == 2, reason: 'step ${i + 1}');
    }
    expect(rays.image.width, side);
    expect(rays.image.height, side);
    expect(rays.debugGeometryRecordings, 2);
  });

  test("the rays are baked again only when the sun's colours change", () {
    final ImageCount count = countImages();
    final MeadowRays rays = MeadowRays(noon)..buildAll();
    addTearDown(rays.dispose);
    final Image baked = rays.image;
    final int revision = rays.revision;
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
    expect(rays.isRecolouring, isFalse);
    expect(baked.debugDisposed, isFalse);
    expect(rays.image, same(baked));
    expect(rays.revision, revision);

    expect(dusk.sunColour, isNot(noon.sunColour));
    final int before = count.created;
    rays.recolour(dusk);
    expect(count.created, before);
    expect(rays.isRecolouring, isTrue);
    expect(rays.image, same(baked));

    rays.step();
    expect(count.created - before, 1);
    expect(rays.image, isNot(same(baked)));
    expect(baked.debugDisposed, isTrue);
    expect(rays.image.debugDisposed, isFalse);
    expect(rays.isRecolouring, isFalse);
    expect(rays.revision, revision + 1);
    expect(rays.debugGeometryRecordings, 2);
  });

  test(
    'a recoloured composite matches rays built fresh with the same palette',
    () async {
      final MeadowRays recoloured = MeadowRays(noon)..buildAll();
      addTearDown(recoloured.dispose);
      recoloured
        ..recolour(dusk)
        ..buildAll();
      final MeadowRays fresh = MeadowRays(dusk)..buildAll();
      addTearDown(fresh.dispose);
      expect(await bytesOf(recoloured.image), await bytesOf(fresh.image));
    },
  );

  test(
    'disposing partly built rays releases only the images they rendered',
    () {
      final ImageCount count = countImages();
      final MeadowRays once = MeadowRays(noon)..step();
      expect(count.created, 1);
      once.dispose();
      expect(count.disposed, count.created);

      final MeadowRays twice = MeadowRays(noon)
        ..step()
        ..step();
      expect(count.created, 3);
      twice.dispose();
      expect(count.disposed, count.created);
    },
  );

  test('a rays recolour is marked only when it differs from the colours of the '
      'shown composite', () async {
    final MeadowPalette midnight = palettes['midnight']!;
    MeadowPalette moved(MeadowPalette palette) =>
        _withSunAt(palette, palette.sunPosition + const Offset(40, 0));
    final Map<String, MeadowPalette?> operations = <String, MeadowPalette?>{
      'noon': noon,
      'noon moved': moved(noon),
      'dusk': dusk,
      'midnight': midnight,
      'midnight moved': moved(midnight),
      'step': null,
    };
    expect(midnight.sunColour, isNot(noon.sunColour));
    expect(midnight.raysGlowAlpha, noon.raysGlowAlpha);
    expect(dusk.sunColour, midnight.sunColour);
    expect(dusk.raysGlowAlpha, isNot(midnight.raysGlowAlpha));
    installPacer(MeadowPacer());
    final ImageCount count = countImages();
    final Map<(Color, double), Uint8List> looks =
        <(Color, double), Uint8List>{};
    for (final MeadowPalette palette in <MeadowPalette>[noon, dusk, midnight]) {
      final MeadowRays reference = MeadowRays(palette)..buildAll();
      looks[(palette.sunColour, palette.raysGlowAlpha)] = await bytesOf(
        reference.image,
      );
      reference.dispose();
    }

    for (final int start in <int>[3, 2]) {
      for (final String first in operations.keys) {
        for (final String second in operations.keys) {
          for (final String third in operations.keys) {
            final List<String> sequence = <String>[first, second, third];
            final String label = 'from $start steps: $sequence';
            final MeadowRays rays = MeadowRays(noon);
            for (int i = 0; i < start; i++) {
              rays.step();
            }
            int made = start;
            (Color, double) requested = (noon.sunColour, noon.raysGlowAlpha);
            (Color, double)? shown = start == 3 ? requested : null;
            for (final String operation in sequence) {
              final MeadowPalette? palette = operations[operation];
              if (palette != null) {
                requested = (palette.sunColour, palette.raysGlowAlpha);
                rays.recolour(palette);
                expect(
                  rays.isRecolouring,
                  shown != null && requested != shown,
                  reason: '$label after recolour($operation)',
                );
                continue;
              }
              final int before = count.created;
              if (made < 3) {
                rays.step();
                made++;
                expect(count.created - before, 1, reason: label);
                if (made == 3) {
                  shown = requested;
                  expect(rays.isReady, isTrue, reason: label);
                  expect(rays.isRecolouring, isFalse, reason: label);
                  expect(
                    await bytesOf(rays.image),
                    looks[shown],
                    reason: '$label first composite',
                  );
                }
                continue;
              }
              final Image previous = rays.image;
              final int revision = rays.revision;
              if (requested != shown) {
                rays.step();
                shown = requested;
                expect(count.created - before, 1, reason: label);
                expect(rays.revision, revision + 1, reason: label);
                expect(previous.debugDisposed, isTrue, reason: label);
                expect(
                  await bytesOf(rays.image),
                  looks[shown],
                  reason: '$label redraw',
                );
              } else {
                rays.step();
                expect(count.created, before, reason: label);
                expect(rays.image, same(previous), reason: label);
                expect(previous.debugDisposed, isFalse, reason: label);
                expect(rays.revision, revision, reason: label);
              }
              expect(rays.isRecolouring, isFalse, reason: label);
            }
            rays.dispose();
          }
        }
      }
    }
  });
}
