import 'dart:ui';

import 'package:field_notes/features/garden/model/garden_insect.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const Size size = Size(400, 300);
  const double skyHeight = 180;

  test('provides two butterflies and one bee', () {
    expect(defaultGardenInsects.length, 3);
    expect(
      defaultGardenInsects
          .where((GardenInsect i) => i.kind == GardenInsectKind.butterfly),
      hasLength(2),
    );
    expect(
      defaultGardenInsects
          .where((GardenInsect i) => i.kind == GardenInsectKind.bee),
      hasLength(1),
    );
  });

  test('gives each insect a distinct phase and band', () {
    expect(
      defaultGardenInsects.map((GardenInsect i) => i.phase).toSet(),
      hasLength(defaultGardenInsects.length),
    );
    expect(
      defaultGardenInsects.map((GardenInsect i) => i.yBand).toSet(),
      hasLength(defaultGardenInsects.length),
    );
  });

  test('stays inside the canvas and above the soil for a full cycle', () {
    for (final GardenInsect insect in defaultGardenInsects) {
      for (int step = 0; step <= 40; step++) {
        final Offset p = insectOffset(insect, step / 40, size, skyHeight);
        expect(p.dx, inInclusiveRange(0, size.width));
        expect(p.dy, inInclusiveRange(0, skyHeight));
      }
    }
  });

  test('drifts horizontally as time advances', () {
    final GardenInsect insect = defaultGardenInsects.first;
    expect(
      insectOffset(insect, 0.0, size, skyHeight).dx,
      isNot(insectOffset(insect, 0.25, size, skyHeight).dx),
    );
  });

  test('is deterministic', () {
    final GardenInsect insect = defaultGardenInsects.first;
    expect(
      insectOffset(insect, 0.3, size, skyHeight),
      insectOffset(insect, 0.3, size, skyHeight),
    );
  });

  test('returns the origin for a degenerate size or sky band', () {
    expect(
      insectOffset(defaultGardenInsects.first, 0.5, Size.zero, skyHeight),
      Offset.zero,
    );
    expect(
      insectOffset(defaultGardenInsects.first, 0.5, size, 0.0),
      Offset.zero,
    );
  });
}
