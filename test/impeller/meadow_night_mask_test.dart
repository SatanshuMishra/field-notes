import 'dart:typed_data';
import 'dart:ui';

import 'package:field_notes/features/garden/model/meadow_random.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/render/meadow_layers.dart';
import 'package:field_notes/features/garden/scene/meadow_grass.dart';
import 'package:field_notes/features/garden/scene/meadow_terrain.dart';
import 'package:field_notes/features/garden/scene/meadow_world.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/garden/support/meadow_pixels.dart';

const double _scale = 0.5;
const Color _overlay = Color(0xE6101828);
const Rect _world = Rect.fromLTWH(0, 0, meadowWorldWidth, meadowWorldHeight);

Future<Uint8List> _render(void Function(Canvas canvas) draw) async {
  final PictureRecorder recorder = PictureRecorder();
  final Canvas canvas = Canvas(recorder)..scale(_scale);
  draw(canvas);
  final Image image = await recorder.endRecording().toImage(
    (meadowWorldWidth * _scale).round(),
    (meadowWorldHeight * _scale).round(),
  );
  final ByteData data = (await image.toByteData(
    format: ImageByteFormat.rawRgba,
  ))!;
  image.dispose();
  return data.buffer.asUint8List();
}

int _channel(double value) => (value * 255).round();

void main() {
  test(
    'the night overlay darkens exactly the land and never lights it',
    () async {
      final MeadowYear year = meadowPixelsLeapYear();
      final int seed = meadowSeed(20280229, meadowPixelsYear);
      final MeadowTerrain terrain = buildMeadowTerrain(seed: seed, year: year);
      final MeadowLayers layers = MeadowLayers(
        terrain: terrain,
        grass: buildMeadowGrass(seed: seed, terrain: terrain),
        density: _scale,
      );
      addTearDown(layers.dispose);
      layers
        ..buildAll()
        ..recolour(meadowPixelsPalettes(year)['midnight']!);
      final MeadowLandMask mask = layers.nightMask;

      final Uint8List masked = await _render((Canvas canvas) {
        canvas
          ..saveLayer(_world, Paint())
          ..drawRect(_world, Paint()..color = _overlay);
        mask.apply(canvas);
        canvas.restore();
      });
      final Uint8List land = await _render((Canvas canvas) {
        final Path path = Path();
        for (final List<Offset> outline in terrain.sky.nightClip) {
          path.addPolygon(outline, true);
        }
        canvas
          ..clipRect(mask.rect)
          ..drawPath(path, Paint()..color = _overlay);
      });

      final int width = (meadowWorldWidth * _scale).round();
      final int ridge = (mask.rect.top * _scale).floor();
      final int top = (mask.rect.top * _scale).ceil();
      final int left = (mask.rect.left * _scale).ceil();
      final int right = (mask.rect.right * _scale).floor();
      final int bottom = (mask.rect.bottom * _scale).floor();
      final int brightest = <int>[
        _channel(_overlay.r),
        _channel(_overlay.g),
        _channel(_overlay.b),
      ].reduce((int a, int b) => a > b ? a : b);

      final int height = (meadowWorldHeight * _scale).round();
      int lit = 0;
      int aboveRidge = 0;
      int outsideChanged = 0;
      final List<int> misses = <int>[];
      for (int y = top; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final bool inside = y < bottom && x >= left && x < right;
          final bool edge =
              y == bottom || x == left - 1 || x == right || y == bottom - 1;
          if (inside || edge) {
            continue;
          }
          final int i = (y * width + x) * 4;
          if ((masked[i + 3] - (_overlay.a * 255).round()).abs() > 1) {
            outsideChanged++;
          }
        }
      }
      for (int y = 0; y < bottom; y++) {
        for (int x = 0; x < width; x++) {
          final int i = (y * width + x) * 4;
          if (masked[i] > brightest + 1 ||
              masked[i + 1] > brightest + 1 ||
              masked[i + 2] > brightest + 1) {
            lit++;
          }
          if (y < ridge) {
            if (masked[i + 3] != 0) {
              aboveRidge++;
            }
          } else if (y >= top && x >= left && x < right) {
            misses.add((masked[i + 3] - land[i + 3]).abs());
          }
        }
      }
      misses.sort();
      printOnFailure(
        'lit $lit aboveRidge $aboveRidge outsideChanged $outsideChanged median ${misses[misses.length ~/ 2]} '
        'p99 ${misses[(misses.length * 0.99).floor()]}',
      );
      expect(lit, 0);
      expect(aboveRidge, 0);
      expect(outsideChanged, 0);
      expect(misses[misses.length ~/ 2], lessThanOrEqualTo(1));
      expect(misses[(misses.length * 0.99).floor()], lessThanOrEqualTo(64));
    },
  );
}
