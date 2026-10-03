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
const double _apart = 1;
const int _maxChannelDelta = 2;

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
) {
  final Offset shift = Offset(noon.glintX, 0);
  final List<MeadowWaterMark> glints = ground.glints
      .map(
        (MeadowGlint glint) => MeadowWaterMark(
          oval: _ovalOf(glint.ellipse, shift: shift),
          colour: noon.glintC,
          opacity: noon.glintO,
        ),
      )
      .fold(
        <MeadowWaterMark>[],
        (List<MeadowWaterMark> kept, MeadowWaterMark mark) =>
            kept.every(
              (MeadowWaterMark other) =>
                  !other.bounds.inflate(_apart).overlaps(mark.bounds),
            )
            ? <MeadowWaterMark>[...kept, mark]
            : kept,
      );
  final MeadowRipple ripple = ground.ripples.first;
  final MeadowFlowMark flow = ground.flows.first;
  return <MeadowWaterMark>[
    ...glints,
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
  ];
}

void _layeredReference(
  Canvas canvas,
  MeadowLayers layers,
  List<MeadowWaterMark> marks,
) {
  canvas.saveLayer(
    layers.water
        .map((MeadowImage tile) => tile.rect)
        .reduce((Rect a, Rect b) => a.expandToInclude(b)),
    Paint(),
  );
  for (final MeadowWaterMark mark in marks) {
    final double? stroke = mark.stroke;
    canvas.drawOval(
      mark.oval,
      Paint()
        ..color = mark.shade
        ..style = stroke == null ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeWidth = stroke ?? 0,
    );
  }
  layers.maskToWater(canvas);
  canvas.restore();
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
  test(
    'the water sparkles drawn without a layer match the layered reference',
    () async {
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
      final List<MeadowWaterMark> marks = _noonMarks(terrain.ground, noon);

      expect(marks.length, greaterThan(10));
      expect(
        marks.where((MeadowWaterMark mark) => mark.stroke != null),
        hasLength(1),
      );
      for (int i = 0; i < marks.length; i++) {
        for (int j = i + 1; j < marks.length; j++) {
          expect(
            marks[i].bounds.overlaps(marks[j].bounds),
            isFalse,
            reason: 'marks $i and $j',
          );
        }
        expect(
          water.where(
            (MeadowImage tile) => marks[i].bounds.overlaps(tile.rect),
          ),
          hasLength(1),
          reason: 'mark $i',
        );
      }

      final Uint8List single = await _render(
        (Canvas canvas) =>
            paintMeadowWaterMarks(canvas, marks: marks, water: water),
      );
      final Uint8List layered = await _render(
        (Canvas canvas) => _layeredReference(canvas, layers, marks),
      );
      expect(single.length, layered.length);
      int worst = 0;
      int sparkling = 0;
      for (int i = 0; i < single.length; i += 4) {
        for (int channel = 0; channel < 4; channel++) {
          final int delta = (single[i + channel] - layered[i + channel]).abs();
          if (delta > worst) {
            worst = delta;
          }
        }
        if (layered[i + 3] > 0) {
          sparkling++;
        }
      }
      printOnFailure('worst $worst sparkling $sparkling');
      expect(sparkling, greaterThan(500));
      expect(worst, lessThanOrEqualTo(_maxChannelDelta));
    },
  );
}
