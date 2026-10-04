import 'dart:typed_data';
import 'dart:ui';

import 'package:field_notes/features/garden/model/meadow_random.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/render/meadow_layers.dart';
import 'package:field_notes/features/garden/render/meadow_water_marks.dart';
import 'package:field_notes/features/garden/scene/meadow_grass.dart';
import 'package:field_notes/features/garden/scene/meadow_palette.dart';
import 'package:field_notes/features/garden/scene/meadow_terrain.dart';
import 'package:field_notes/features/garden/scene/meadow_world.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/garden/support/meadow_pixels.dart';

const double _density = 1;
const double _scale = 1.5;
const double _rippleScale = 1.4;
const double _rippleOpacity = 0.8;
const Size _shoreMark = Size(80, 24);
const int _visibleAlpha = 2;

Rect _ovalOf(
  MeadowEllipse ellipse, {
  Offset shift = Offset.zero,
  double scale = 1,
}) => Rect.fromCenter(
  center: ellipse.centre + shift,
  width: ellipse.radiusX * 2 * scale,
  height: ellipse.radiusY * 2 * scale,
);

List<MeadowWaterMark> _noonMarks(
  MeadowGroundDressing ground,
  MeadowPalette noon,
  Rect shoreMark,
) {
  final Offset shift = Offset(noon.glintX, 0);
  final MeadowRipple ripple = ground.ripples.first;
  final MeadowFlowMark flow = ground.flows.first;
  return <MeadowWaterMark>[
    for (final MeadowGlint glint in ground.glints)
      MeadowWaterMark(
        oval: _ovalOf(glint.ellipse, shift: shift),
        colour: noon.glintC,
        opacity: noon.glintO,
      ),
    MeadowWaterMark(
      oval: _ovalOf(ripple.ellipse, scale: _rippleScale),
      colour: noon.flowC,
      opacity: _rippleOpacity,
      stroke: MeadowRipple.strokeWidth * _rippleScale,
    ),
    MeadowWaterMark(
      oval: _ovalOf(flow.ellipse),
      colour: noon.flowC,
      opacity: noon.flowO,
    ),
    MeadowWaterMark(oval: shoreMark, colour: noon.glintC, opacity: 1),
  ];
}

Future<Uint8List> _render(void Function(Canvas canvas) draw) async {
  final PictureRecorder recorder = PictureRecorder();
  final Canvas canvas = Canvas(recorder)..scale(_scale);
  draw(canvas);
  final Image image = await recorder.endRecording().toImage(
    (meadowWorldWidth * _scale).round(),
    (meadowWorldHeight * _scale).round(),
  );
  final Uint8List rgba = await rgbaOf(image);
  image.dispose();
  return rgba;
}

void main() {
  test('the water sparkles are drawn in one pass and show only where the water '
      'is', () async {
    final MeadowYear year = meadowPixelsLeapYear();
    final int seed = meadowSeed(20280229, meadowPixelsYear);
    final MeadowTerrain terrain = buildMeadowTerrain(seed: seed, year: year);
    final MeadowLayers layers = MeadowLayers(
      terrain: terrain,
      grass: buildMeadowGrass(seed: seed, terrain: terrain),
      density: _density,
    );
    addTearDown(layers.dispose);
    final MeadowPalette noon = meadowPixelsPalettes(year)['noon']!;
    expect(noon.glintO, greaterThan(0));
    layers
      ..recolour(noon)
      ..buildAll();
    final List<MeadowImage> water = layers.water;
    expect(water, isNotEmpty);
    final Rect uppermost = water
        .map((MeadowImage tile) => tile.rect)
        .reduce((Rect a, Rect b) => a.top <= b.top ? a : b);
    final Rect shoreMark = Rect.fromCenter(
      center: uppermost.topCenter,
      width: _shoreMark.width,
      height: _shoreMark.height,
    );
    final List<MeadowWaterMark> marks = _noonMarks(
      terrain.ground,
      noon,
      shoreMark,
    );
    expect(marks.length, greaterThan(10));

    final Uint8List sparkles = await _render(
      (Canvas canvas) =>
          paintMeadowWaterMarks(canvas, marks: marks, layers: layers),
    );
    final Uint8List lake = await _render((Canvas canvas) {
      final Paint sampled = Paint()..filterQuality = FilterQuality.low;
      for (final MeadowImage tile in water) {
        canvas.drawImageRect(tile.image, tile.source, tile.rect, sampled);
      }
    });
    expect(sparkles.length, lake.length);

    final int width = (meadowWorldWidth * _scale).round();
    final int shoreRow = (uppermost.top * _scale).floor();
    int sparkling = 0;
    int offWater = 0;
    int belowShore = 0;
    int aboveShore = 0;
    for (int i = 0; i < sparkles.length; i += 4) {
      if (sparkles[i + 3] <= _visibleAlpha) {
        continue;
      }
      sparkling++;
      if (lake[i + 3] == 0) {
        offWater++;
      }
      final int pixel = i ~/ 4;
      final double x = (pixel % width) / _scale;
      final int row = pixel ~/ width;
      if (x >= shoreMark.left && x <= shoreMark.right) {
        if (row < shoreRow) {
          aboveShore++;
        } else if (row <= ((shoreMark.bottom) * _scale).ceil()) {
          belowShore++;
        }
      }
    }
    printOnFailure(
      'sparkling $sparkling offWater $offWater above $aboveShore '
      'below $belowShore',
    );
    expect(sparkling, greaterThan(500));
    expect(offWater, 0);
    expect(belowShore, greaterThan(0));
    expect(aboveShore, 0);
  });
}
