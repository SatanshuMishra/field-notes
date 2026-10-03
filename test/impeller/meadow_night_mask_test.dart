import 'dart:typed_data';
import 'dart:ui';

import 'package:field_notes/features/garden/model/meadow_random.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/render/meadow_layers.dart';
import 'package:field_notes/features/garden/render/meadow_night_overlay.dart';
import 'package:field_notes/features/garden/scene/meadow_grass.dart';
import 'package:field_notes/features/garden/scene/meadow_palette.dart';
import 'package:field_notes/features/garden/scene/meadow_terrain.dart';
import 'package:field_notes/features/garden/scene/meadow_world.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/garden/support/meadow_pixels.dart';

const double _scale = 0.5;
const int _maxChannelDelta = 2;
const Rect _world = Rect.fromLTWH(0, 0, meadowWorldWidth, meadowWorldHeight);

Future<Uint8List> _render(
  double pixelAlignment,
  void Function(Canvas canvas) draw,
) async {
  final PictureRecorder recorder = PictureRecorder();
  final Canvas canvas = Canvas(recorder)
    ..translate(0, pixelAlignment)
    ..scale(_scale)
    ..clipRect(_world);
  draw(canvas);
  final Image image = await recorder.endRecording().toImage(
    (meadowWorldWidth * _scale).round(),
    (meadowWorldHeight * _scale).round(),
  );
  final Uint8List rgba = await rgbaOf(image);
  image.dispose();
  return rgba;
}

int _channel(double value) => (value * 255).round();

void main() {
  testWidgets(
    'the night overlay darkens exactly the land and never lights it',
    (WidgetTester tester) async {
      final FragmentProgram? program = await tester.runAsync(
        loadMeadowNightOverlay,
      );
      expect(program, isNotNull);
      final MeadowYear year = meadowPixelsLeapYear();
      final int seed = meadowSeed(20280229, meadowPixelsYear);
      final MeadowTerrain terrain = buildMeadowTerrain(seed: seed, year: year);
      final MeadowLayers layers = MeadowLayers(
        terrain: terrain,
        grass: buildMeadowGrass(seed: seed, terrain: terrain),
        density: _scale,
      );
      addTearDown(layers.dispose);
      final MeadowPalette midnight = meadowPixelsPalettes(year)['midnight']!;
      expect(midnight.overlayAlpha, greaterThan(0));
      layers
        ..recolour(midnight)
        ..buildAll();
      final Rect land = layers.nightMask.rect;
      final double top = land.top * _scale;
      final double pixelAlignment = top.ceilToDouble() - top;
      final double bottom = land.bottom * _scale + pixelAlignment;
      expect(bottom, closeTo(bottom.roundToDouble(), 1e-6));

      final Uint8List? single = await tester.runAsync(
        () => _render(
          pixelAlignment,
          (Canvas canvas) => paintMeadowNightOverlay(
            canvas,
            program: program!,
            layers: layers,
            palette: midnight,
          ),
        ),
      );
      final Uint8List? layered = await tester.runAsync(
        () => _render(
          pixelAlignment,
          (Canvas canvas) => paintMeadowNightOverlayLayered(
            canvas,
            layers: layers,
            palette: midnight,
          ),
        ),
      );
      expect(single, isNotNull);
      expect(layered, isNotNull);
      expect(single!.length, layered!.length);

      final int width = (meadowWorldWidth * _scale).round();
      final int ridge = top.ceil();
      final Color overlay = midnight.overlayColour;
      final int brightest = <int>[
        _channel(overlay.r),
        _channel(overlay.g),
        _channel(overlay.b),
      ].reduce((int a, int b) => a > b ? a : b);
      int worst = 0;
      int shaded = 0;
      int lit = 0;
      int aboveRidge = 0;
      for (int i = 0; i < single.length; i += 4) {
        for (int channel = 0; channel < 4; channel++) {
          final int delta = (single[i + channel] - layered[i + channel]).abs();
          if (delta > worst) {
            worst = delta;
          }
        }
        if (layered[i + 3] > 0) {
          shaded++;
        }
        if (single[i] > brightest + 1 ||
            single[i + 1] > brightest + 1 ||
            single[i + 2] > brightest + 1) {
          lit++;
        }
        if ((i ~/ 4) ~/ width < ridge && single[i + 3] != 0) {
          aboveRidge++;
        }
      }
      printOnFailure('worst $worst shaded $shaded lit $lit above $aboveRidge');
      expect(shaded, greaterThan(single.length ~/ 4 ~/ 4));
      expect(lit, 0);
      expect(aboveRidge, 0);
      expect(worst, lessThanOrEqualTo(_maxChannelDelta));
    },
  );
}
