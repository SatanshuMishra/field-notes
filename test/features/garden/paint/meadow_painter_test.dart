import 'dart:ui';

import 'package:field_notes/domain/mood/flower_kind.dart';
import 'package:field_notes/features/garden/model/garden_insect.dart';
import 'package:field_notes/features/garden/model/meadow_layout.dart';
import 'package:field_notes/features/garden/paint/meadow_painter.dart';
import 'package:flutter_test/flutter_test.dart';

const List<PlantedBloom> _planted = <PlantedBloom>[
  PlantedBloom(
    kind: FlowerKind.peony,
    dx: 120,
    baseY: 220,
    size: 60,
    swayPhase: 0.5,
    swayAmplitude: 0.03,
  ),
  PlantedBloom(
    kind: FlowerKind.bleedingHeart,
    dx: 200,
    baseY: 235,
    size: 64,
    swayPhase: 0.9,
    swayAmplitude: 0.02,
  ),
  PlantedBloom(
    kind: FlowerKind.redSpiderLily,
    dx: 260,
    baseY: 250,
    size: 70,
    swayPhase: 1.2,
    swayAmplitude: 0.04,
  ),
];

Picture _render(MeadowPainter painter, Size size) {
  final PictureRecorder recorder = PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  painter.paint(canvas, size);
  return recorder.endRecording();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const Size size = Size(400, 300);

  test('paints blooms and insects without throwing', () {
    const MeadowPainter painter = MeadowPainter(
      t: 0.25,
      planted: _planted,
      insects: defaultGardenInsects,
      showInsects: true,
    );
    expect(() => _render(painter, size), returnsNormally);
  });

  test('paints a degraded, insect-free frame without throwing', () {
    const MeadowPainter painter = MeadowPainter(
      t: 0.0,
      planted: _planted,
      insects: defaultGardenInsects,
      showInsects: false,
    );
    expect(() => _render(painter, size), returnsNormally);
  });

  test('paints an empty meadow without throwing', () {
    const MeadowPainter painter = MeadowPainter(
      t: 0.5,
      planted: <PlantedBloom>[],
      insects: <GardenInsect>[],
      showInsects: true,
    );
    expect(() => _render(painter, size), returnsNormally);
  });

  test('repaints on animation tick but not on identical inputs', () {
    const MeadowPainter a = MeadowPainter(
      t: 0.10,
      planted: _planted,
      insects: defaultGardenInsects,
      showInsects: true,
    );
    const MeadowPainter same = MeadowPainter(
      t: 0.10,
      planted: _planted,
      insects: defaultGardenInsects,
      showInsects: true,
    );
    const MeadowPainter ticked = MeadowPainter(
      t: 0.20,
      planted: _planted,
      insects: defaultGardenInsects,
      showInsects: true,
    );
    const MeadowPainter degraded = MeadowPainter(
      t: 0.10,
      planted: _planted,
      insects: defaultGardenInsects,
      showInsects: false,
    );
    expect(a.shouldRepaint(same), isFalse);
    expect(a.shouldRepaint(ticked), isTrue);
    expect(a.shouldRepaint(degraded), isTrue);
  });
}
