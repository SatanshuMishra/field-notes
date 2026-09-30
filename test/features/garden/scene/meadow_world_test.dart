import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:field_notes/features/garden/scene/meadow_world.dart';

void main() {
  test('the projection puts January at the far lake and December in front', () {
    expect(meadowDepthOf(0), closeTo(3.5, 1e-4));
    expect(meadowDepthOf(0.5), closeTo(1.591611, 1e-4));
    expect(meadowDepthOf(1), closeTo(1.03, 1e-4));

    const List<List<double>> expected = <List<double>>[
      <double>[0, 800.0, 378.5714, 0.205714],
      <double>[0.5, 919.9029, 489.5673, 0.452372],
      <double>[1, 1039.8058, 600.5631, 0.699029],
    ];
    for (final List<double> row in expected) {
      final MeadowPoint p = meadowProject(0.5, meadowDepthOf(row[0]));
      expect(p.x, closeTo(row[1], 1e-4));
      expect(p.y, closeTo(row[2], 1e-4));
      expect(p.scale, closeTo(row[3], 1e-4));
    }

    for (final double u in <double>[0, 0.25, 0.5, 0.9, 1]) {
      expect(meadowProgressOfDepth(meadowDepthOf(u)), closeTo(u, 1e-9));
    }
    expect(meadowDayProgress(0, 366), 0);
    expect(meadowDayProgress(365, 366), 1);
  });

  test('the viewport fits or covers the world and clamps the pan', () {
    final MeadowViewport fit = MeadowViewport.resolve(
      box: const Size(1100, 503),
      cover: false,
      focusX: 700,
    );
    expect(fit.scale, closeTo(1100 / 1400, 1e-9));
    expect(fit.offset, Offset.zero);
    expect(fit.pan, 0);

    const Size box = Size(400, 300);
    const double scale = 300 / 640;
    const double visible = 400 / scale;
    final MeadowViewport centred = MeadowViewport.resolve(
      box: box,
      cover: true,
      focusX: 700,
    );
    expect(centred.scale, closeTo(scale, 1e-9));
    expect(centred.pan, closeTo(700 - visible / 2, 1e-9));
    expect(centred.offset.dx, closeTo(-centred.pan * scale, 1e-9));
    expect(centred.offset.dy, closeTo(0, 1e-9));

    expect(MeadowViewport.resolve(box: box, cover: true, focusX: 10).pan, 0);
    expect(
      MeadowViewport.resolve(box: box, cover: true, focusX: 1390).pan,
      closeTo(1400 - visible, 1e-9),
    );
    expect(
      MeadowViewport.resolve(box: box, cover: true, pan: 5000, focusX: 0).pan,
      closeTo(1400 - visible, 1e-9),
    );

    final Offset world = centred.toWorld(const Offset(200, 150));
    final Offset back = centred.toLocal(world);
    expect(back.dx, closeTo(200, 1e-9));
    expect(back.dy, closeTo(150, 1e-9));
  });
}
