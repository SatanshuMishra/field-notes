import 'dart:typed_data';
import 'dart:ui';

import 'package:field_notes/features/garden/model/meadow_random.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/render/meadow_layers.dart';
import 'package:field_notes/features/garden/scene/meadow_grass.dart';
import 'package:field_notes/features/garden/scene/meadow_pacer.dart';
import 'package:field_notes/features/garden/scene/meadow_palette.dart';
import 'package:field_notes/features/garden/scene/meadow_terrain.dart';
import 'package:field_notes/features/garden/scene/meadow_world.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/image_count.dart';
import '../support/meadow_pixels.dart';

const double _phoneRatio = 2.625;
const double _macRatio = 2;
const Size _phoneScreen = Size(1080 / _phoneRatio, 2280 / _phoneRatio);
const Size _sidebarCard = Size(1100, 502.9);
const Size _bottomBarCard = Size(400, 300);
const int _lap = 21;
const int _lakeTiles = 7;

int _changedPixels(Uint8List first, Uint8List second) {
  int changed = 0;
  for (int i = 0; i < first.length; i += 4) {
    if (first[i] != second[i] ||
        first[i + 1] != second[i + 1] ||
        first[i + 2] != second[i + 2] ||
        first[i + 3] != second[i + 3]) {
      changed++;
    }
  }
  return changed;
}

double _viewportDensity(
  Size box, {
  required bool cover,
  required double ratio,
}) => MeadowViewport.resolve(box: box, cover: cover, focusX: 700).scale * ratio;

List<Image> _pieces(MeadowLayers layers) => <Image>[
  layers.mountains.image,
  for (final MeadowImage tile in layers.water) tile.image,
  for (final MeadowFallLayer fall in layers.falls) fall.body.image,
  for (final MeadowCloudImage cloud in layers.clouds) cloud.image.image,
];

List<Image> _fallImages(MeadowFallLayer fall) => <Image>[
  fall.body.image,
  fall.pool.image,
  for (final MeadowStreakStrip streak in fall.streaks) streak.tile,
];

List<Image> _everyImage(MeadowLayers layers) => <Image>[
  layers.mountains.image,
  for (final MeadowImage tile in layers.water) tile.image,
  for (final MeadowFallLayer fall in layers.falls) ..._fallImages(fall),
  for (final MeadowCloudImage cloud in layers.clouds) cloud.image.image,
];

List<int> _redrawn(List<Image> before, List<Image> after) => <int>[
  for (int i = 0; i < before.length; i++)
    if (!identical(before[i], after[i])) i,
];

MeadowPacer _installPacer(MeadowPacer pacer) {
  final MeadowPacer original = meadowPacer;
  meadowPacer = pacer;
  addTearDown(() => meadowPacer = original);
  return pacer;
}

ImageCount _countImages() {
  final ImageCount count = ImageCount()..start();
  addTearDown(count.stop);
  return count;
}

void main() {
  final MeadowYear year = meadowPixelsLeapYear();
  final int seed = meadowSeed(20280229, meadowPixelsYear);
  final MeadowTerrain terrain = buildMeadowTerrain(seed: seed, year: year);
  final List<MeadowGrassBand> grass = buildMeadowGrass(
    seed: seed,
    terrain: terrain,
  );
  final Map<String, MeadowPalette> palettes = meadowPixelsPalettes(year);
  final MeadowPalette noon = palettes['noon']!;
  final MeadowPalette dusk = palettes['dusk']!;
  final MeadowPalette midnight = palettes['midnight']!;

  MeadowLayers testLayers() {
    final MeadowLayers layers = MeadowLayers(
      terrain: terrain,
      grass: grass,
      density: 0.5,
    );
    addTearDown(layers.dispose);
    return layers;
  }

  MeadowLayers colouredLayers(MeadowPalette palette) => testLayers()
    ..recolour(palette)
    ..buildAll();

  Future<void> expectSameImages(
    MeadowLayers layers,
    MeadowLayers fresh,
    String reason,
  ) async {
    final List<Image> settled = _everyImage(layers);
    final List<Image> direct = _everyImage(fresh);
    expect(settled, hasLength(direct.length), reason: reason);
    for (int i = 0; i < direct.length; i++) {
      expect(
        await rgbaOf(settled[i]),
        await rgbaOf(direct[i]),
        reason: '$reason, image $i',
      );
    }
  }

  test('a sky change recolours the landscape without rebuilding it', () async {
    final MeadowLayers layers = MeadowLayers(
      terrain: terrain,
      grass: grass,
      density: 0.5,
    );
    addTearDown(layers.dispose);
    layers
      ..recolour(noon)
      ..buildAll();
    expect(layers.isReady, isTrue);
    final int recorded = layers.geometryRecordings;
    expect(recorded, greaterThan(0));
    final Uint8List day = await rgbaOf(layers.mountains.image);

    layers
      ..recolour(midnight)
      ..buildAll();

    expect(layers.geometryRecordings, recorded);
    final Uint8List night = await rgbaOf(layers.mountains.image);
    expect(night, hasLength(day.length));
    expect(_changedPixels(day, night), greaterThan(day.length ~/ 4 ~/ 4));
  });

  test('the landscape images fit the memory ceiling', () {
    final List<(String, double, int)> views = <(String, double, int)>[
      (
        'full screen on the phone',
        _viewportDensity(_phoneScreen, cover: true, ratio: _phoneRatio),
        meadowLayerBudget,
      ),
      (
        'sidebar page',
        _viewportDensity(_sidebarCard, cover: false, ratio: _macRatio),
        meadowLayerPageBudget,
      ),
      (
        'bottom-bar page',
        _viewportDensity(_bottomBarCard, cover: true, ratio: _phoneRatio),
        meadowLayerPageBudget,
      ),
    ];
    for (final (String name, double wanted, int budget) in views) {
      final double density = MeadowLayers.fitDensity(
        terrain: terrain,
        grass: grass,
        density: wanted,
        maxBytes: budget,
      );
      final MeadowLayers layers = MeadowLayers(
        terrain: terrain,
        grass: grass,
        density: density,
      );
      layers
        ..recolour(noon)
        ..buildAll();

      expect(layers.imageBytes, lessThanOrEqualTo(budget), reason: name);
      expect(
        layers.imageBytes,
        MeadowLayers.bytesAt(terrain: terrain, grass: grass, density: density),
        reason: name,
      );
      expect(density, lessThanOrEqualTo(wanted), reason: name);

      layers.dispose();
      expect(layers.imageBytes, 0, reason: name);
    }
  });

  test(
    'the recoloured mountains match drawing the prototype layers directly',
    () async {
      final MeadowLayers layers = MeadowLayers(
        terrain: terrain,
        grass: grass,
        density: 1,
      );
      addTearDown(layers.dispose);
      layers.buildAll();
      for (final MeadowPalette palette in <MeadowPalette>[
        noon,
        dusk,
        midnight,
        noon,
      ]) {
        layers
          ..recolour(palette)
          ..buildAll();
        final Uint8List recoloured = await rgbaOf(layers.mountains.image);
        final Image direct = layers.drawMountainsDirectly(palette);
        final Uint8List drawn = await rgbaOf(direct);
        direct.dispose();
        final List<int> worst = sortedPixelDifferences(drawn, recoloured);
        final int median = percentileOf(worst, 0.5);
        final int nearlyAll = percentileOf(worst, 0.995);
        expect(median, lessThanOrEqualTo(1));
        expect(nearlyAll, lessThanOrEqualTo(4));
      }
    },
  );

  test('a recolour completes one piece at a time, the mountains first and the '
      'lake straight after', () {
    final MeadowLayers layers = colouredLayers(noon);
    expect(layers.isReady, isTrue);
    expect(layers.water, hasLength(7));
    expect(layers.falls, hasLength(2));
    expect(layers.clouds, hasLength(5));
    final List<Image> before = _pieces(layers);
    expect(before, hasLength(15));

    layers.recolour(midnight);

    expect(
      _redrawn(before, _pieces(layers)),
      isEmpty,
      reason: 'the recolour call itself redraws nothing',
    );
    final List<int> order = <int>[];
    final List<int> ownSteps = <int>[];
    List<Image> previous = before;
    int steps = 0;
    int sinceLast = 0;
    while (layers.isRecolouring && steps < 100) {
      layers.step();
      steps++;
      sinceLast++;
      final List<Image> now = _pieces(layers);
      final List<int> redrawn = _redrawn(previous, now);
      expect(redrawn.length, lessThanOrEqualTo(1), reason: 'step $steps');
      if (redrawn.isNotEmpty) {
        order.add(redrawn.single);
        ownSteps.add(sinceLast);
        sinceLast = 0;
      }
      previous = now;
    }
    expect(layers.isRecolouring, isFalse);
    expect(steps, 21);
    expect(order, <int>[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14]);
    expect(ownSteps, <int>[1, 1, 1, 1, 1, 1, 1, 1, 4, 4, 1, 1, 1, 1, 1]);
    expect(layers.step(), isFalse);
    expect(_redrawn(previous, _pieces(layers)), isEmpty);
  });

  test('the layers are not ready until every piece has its first colours', () {
    final MeadowLayers layers = testLayers();
    layers.recolour(noon);
    while (!layers.isBuilt) {
      layers.step();
    }

    expect(layers.isReady, isFalse, reason: 'built but not yet coloured');
    int steps = 0;
    while (!layers.isReady && steps < 100) {
      final int revision = layers.revision;
      layers.step();
      steps++;
      expect(
        layers.revision - revision,
        lessThanOrEqualTo(1),
        reason: 'step $steps completes at most one piece',
      );
    }
    expect(layers.isReady, isTrue);
    expect(steps, 21);
  });

  test('while the sky keeps changing every piece keeps up and the lake follows the mountains', () async {
    final MeadowLayers layers = colouredLayers(noon);
    final int count = _pieces(layers).length;
    expect(count, 15);
    expect(layers.water, hasLength(_lakeTiles));
    final List<MeadowPalette> sweep = <MeadowPalette>[dusk, midnight, noon];
    final List<int> lastDrawn = List<int>.filled(count, 0);
    final List<int> order = <int>[];
    List<Image> previous = _pieces(layers);
    for (int step = 1; step <= 3 * _lap; step++) {
      layers.recolour(sweep[step % sweep.length]);
      expect(
        _redrawn(previous, _pieces(layers)),
        isEmpty,
        reason: 'the recolour call at step $step',
      );
      layers.step();
      final List<Image> now = _pieces(layers);
      final List<int> redrawn = _redrawn(previous, now);
      expect(redrawn.length, lessThanOrEqualTo(1), reason: 'step $step');
      for (final int piece in redrawn) {
        lastDrawn[piece] = step;
        order.add(piece);
      }
      if (step >= _lap) {
        for (int i = 0; i < count; i++) {
          expect(
            step - lastDrawn[i],
            lessThan(_lap),
            reason: 'piece $i at step $step',
          );
        }
      }
      previous = now;
    }
    for (int i = 0; i < order.length; i++) {
      if (order[i] == 0) {
        for (
          int tile = 1;
          tile <= _lakeTiles && i + tile < order.length;
          tile++
        ) {
          expect(
            order[i + tile],
            tile,
            reason: 'after the mountains at completion ${i + 1}',
          );
        }
      }
    }

    layers.recolour(midnight);
    int calls = 0;
    bool more = true;
    while (more && calls <= 24) {
      more = layers.step();
      calls++;
    }
    expect(more, isFalse);
    expect(calls, lessThanOrEqualTo(24));

    await expectSameImages(layers, colouredLayers(midnight), 'midnight');
  });

  test(
    'every layer step renders at most one image, building and recolouring',
    () {
      final ImageCount count = _countImages();
      final MeadowLayers layers = testLayers();
      layers.recolour(noon);
      int steps = 0;
      while (!layers.isReady && steps < 1000) {
        final int before = count.created;
        layers.step();
        steps++;
        expect(
          count.created - before,
          lessThanOrEqualTo(1),
          reason: 'build step $steps',
        );
      }
      expect(layers.isReady, isTrue);
      expect(count.created, 151);

      final int built = count.created;
      layers.recolour(midnight);
      steps = 0;
      while (layers.isRecolouring && steps < 1000) {
        final int before = count.created;
        layers.step();
        steps++;
        expect(
          count.created - before,
          lessThanOrEqualTo(1),
          reason: 'recolour step $steps',
        );
      }
      expect(layers.isRecolouring, isFalse);
      expect(count.created - built, 21);
    },
  );

  test('a waterfall recolour swaps its body, pool and streak tiles together '
      'after its last part', () {
    final MeadowLayers layers = colouredLayers(noon);
    layers.recolour(midnight);
    for (int i = 0; i < 8; i++) {
      layers.step();
    }
    final ImageCount count = _countImages();
    final List<Image> shown = _fallImages(layers.falls.first);
    expect(shown, hasLength(4));
    final int revision = layers.revision;
    for (int i = 0; i < 3; i++) {
      final int before = count.created;
      layers.step();
      expect(count.created - before, 1, reason: 'part ${i + 1}');
      final List<Image> now = _fallImages(layers.falls.first);
      expect(now, hasLength(shown.length));
      for (int image = 0; image < shown.length; image++) {
        expect(
          now[image],
          same(shown[image]),
          reason: 'part ${i + 1}, image $image',
        );
      }
      expect(layers.revision, revision, reason: 'part ${i + 1}');
    }
    final int before = count.created;
    layers.step();
    expect(count.created - before, 1);
    final List<Image> swapped = _fallImages(layers.falls.first);
    expect(swapped, hasLength(shown.length));
    for (int image = 0; image < shown.length; image++) {
      expect(swapped[image], isNot(same(shown[image])), reason: '$image');
    }
    expect(layers.revision, revision + 1);
  });

  test('a colour change during a waterfall redraw leaves it for another redraw '
      'with the newest colours', () async {
    final MeadowLayers fresh = colouredLayers(dusk);

    final MeadowLayers recolouring = colouredLayers(noon);
    recolouring.recolour(midnight);
    for (int i = 0; i < 10; i++) {
      recolouring.step();
    }
    final List<Image> shown = _fallImages(recolouring.falls.first);
    final int revision = recolouring.revision;
    recolouring.recolour(dusk);
    recolouring.step();
    expect(
      _redrawn(shown, _fallImages(recolouring.falls.first)),
      isEmpty,
      reason: 'the third part is kept aside',
    );
    expect(recolouring.revision, revision);
    recolouring.step();
    expect(_redrawn(shown, _fallImages(recolouring.falls.first)), <int>[
      0,
      1,
      2,
      3,
    ], reason: 'the fourth part swaps every part at once');
    expect(recolouring.revision, revision + 1);
    expect(recolouring.isRecolouring, isTrue);
    int steps = 0;
    while ((!recolouring.isReady || recolouring.isRecolouring) && steps < 100) {
      recolouring.step();
      steps++;
    }
    expect(recolouring.isReady, isTrue);
    expect(recolouring.isRecolouring, isFalse);
    await expectSameImages(recolouring, fresh, 'during a recolour');

    final MeadowLayers opening = testLayers();
    opening.recolour(noon);
    while (!opening.isBuilt) {
      opening.step();
    }
    for (int i = 0; i < 10; i++) {
      opening.step();
    }
    opening.recolour(dusk);
    steps = 0;
    while ((!opening.isReady || opening.isRecolouring) && steps < 100) {
      opening.step();
      steps++;
    }
    expect(opening.isReady, isTrue);
    expect(opening.isRecolouring, isFalse);
    await expectSameImages(opening, fresh, 'during the first colours');
  });

  test(
    'building and recolouring the layers counts every image they render',
    () {
      final MeadowPacer pacer = _installPacer(MeadowPacer());
      final ImageCount count = _countImages();
      final MeadowLayers layers = testLayers();
      layers.recolour(noon);
      int steps = 0;
      while (!layers.isReady && steps < 1000) {
        layers.step();
        steps++;
      }
      expect(layers.isReady, isTrue);
      expect(count.created, 151);
      expect(pacer.debugSnapshots, 151);
      expect(meadowPacer.debugSnapshots, count.created);

      layers.recolour(midnight);
      steps = 0;
      while (layers.isRecolouring && steps < 1000) {
        layers.step();
        steps++;
      }
      expect(layers.isRecolouring, isFalse);
      expect(count.created, 172);
      expect(pacer.debugSnapshots, 172);
      expect(meadowPacer.debugSnapshots, count.created);
    },
  );
}
