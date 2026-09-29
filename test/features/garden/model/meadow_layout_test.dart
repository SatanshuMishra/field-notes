import 'dart:math' as math;
import 'dart:ui';

import 'package:field_notes/design/flowers/garden_plant_painter.dart';
import 'package:field_notes/design/flowers/garden_plant_spec.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/garden/model/garden_data.dart';
import 'package:field_notes/features/garden/model/meadow_layout.dart';
import 'package:flutter_test/flutter_test.dart';

List<GardenBloomData> _blooms(int n) => List<GardenBloomData>.generate(
  n,
  (int i) => GardenBloomData(
    date:
        '2026-${(i ~/ 28 + 1).toString().padLeft(2, '0')}-'
        '${(i % 28 + 1).toString().padLeft(2, '0')}',
    mood: moodOrder[i % moodOrder.length],
  ),
);

double _meanGap(List<MeadowPlant> plants, {required bool sameMood}) {
  double total = 0;
  int pairs = 0;
  for (int i = 0; i < plants.length; i++) {
    for (int j = i + 1; j < plants.length; j++) {
      if ((plants[i].kind == plants[j].kind) != sameMood) {
        continue;
      }
      total += (plants[i].dx - plants[j].dx).abs();
      pairs++;
    }
  }
  return total / pairs;
}

void main() {
  const Size card = Size(1000, 452);
  const Size phoneCard = Size(380, 320);

  test('far plants stand higher, smaller and hazier than near plants', () {
    final MeadowLayout layout = layoutMeadowByDepth(
      blooms: _blooms(60),
      size: card,
      seed: 2026,
    );
    final List<MeadowPlant> plants = <MeadowPlant>[...layout.plants]
      ..sort((MeadowPlant a, MeadowPlant b) => a.depth.compareTo(b.depth));
    final MeadowPlant far = plants.first;
    final MeadowPlant near = plants.last;

    expect(far.depth, lessThan(0.3));
    expect(near.depth, greaterThan(0.85));
    expect(far.bottom, greaterThan(near.bottom));
    expect(far.width, lessThan(near.width));
    expect(far.height, lessThan(near.height));
    expect(far.opacity, lessThan(near.opacity));
    expect(far.blur, greaterThan(near.blur));
    expect(near.blur, 0);

    for (final MeadowPlant plant in plants) {
      final double d = plant.depth;
      expect(d, inInclusiveRange(0, 1));
      expect(plant.width, closeTo(54 * (0.4 + 0.9 * d), 1e-9));
      expect(
        plant.height,
        closeTo(plant.width * gardenPlantSpecFor(plant.kind).ratio, 1e-9),
      );
      expect(plant.bottom, closeTo((1 - d) * card.height * 0.5 - d * 6, 1e-9));
      expect(plant.opacity, closeTo(0.6 + 0.4 * d, 1e-9));
      expect(plant.blur, closeTo(d <= 0.82 ? (1 - d) * 1.7 : 0, 1e-9));
      expect(plant.swayDegrees, 2.2);
      expect(plant.swayPeriod, inInclusiveRange(3.6, 6));
      expect(plant.swayPhase, inInclusiveRange(0, plant.swayPeriod));
      expect(
        plant.dx,
        inInclusiveRange(0.015 * card.width, 0.985 * card.width),
      );
    }

    final MeadowLayout phone = layoutMeadowByDepth(
      blooms: _blooms(20),
      size: phoneCard,
      seed: 2026,
      compact: true,
    );
    for (final MeadowPlant plant in phone.plants) {
      expect(plant.width, closeTo(38 * (0.4 + 0.9 * plant.depth), 1e-9));
    }
  });

  test('blooms of one mood grow in drifts', () {
    final List<MeadowPlant> plants = layoutMeadowByDepth(
      blooms: _blooms(60),
      size: card,
      seed: 2026,
    ).plants;

    expect(plants, hasLength(60));
    final double together = _meanGap(plants, sameMood: true);
    final double apart = _meanGap(plants, sameMood: false);
    expect(together, lessThan(apart));
    expect(together, lessThan(0.1 * card.width));
  });

  test('grass tufts scatter through the meadow with a front band', () {
    for (final int count in <int>[0, 1, 20, 60]) {
      final MeadowLayout desktop = layoutMeadowByDepth(
        blooms: _blooms(count),
        size: card,
        seed: 2026,
      );
      final MeadowLayout phone = layoutMeadowByDepth(
        blooms: _blooms(count),
        size: phoneCard,
        seed: 2026,
        compact: true,
      );
      expect(desktop.tufts, hasLength((0.85 * count).round() + 14));
      expect(phone.tufts, hasLength((0.85 * count).round() + 7));

      for (final (MeadowLayout layout, int band) in <(MeadowLayout, int)>[
        (desktop, 14),
        (phone, 7),
      ]) {
        final Size size = layout.size;
        for (int slot = 0; slot < band; slot++) {
          final double from = slot / band * size.width;
          final double to = (slot + 0.7) / band * size.width;
          expect(
            layout.tufts.where(
              (MeadowTuft tuft) =>
                  tuft.depth >= 0.9 && tuft.dx >= from && tuft.dx <= to,
            ),
            isNotEmpty,
            reason: 'front band slot $slot of $band',
          );
        }
        for (final MeadowTuft tuft in layout.tufts) {
          final double d = tuft.depth;
          final double base = identical(layout, phone) ? 24 : 34;
          expect(d, inInclusiveRange(0, 1.02));
          expect(tuft.dx, inInclusiveRange(0, size.width));
          expect(tuft.width, closeTo(base * (0.5 + 0.95 * d), 1e-9));
          expect(tuft.height, closeTo(tuft.width * 0.9, 1e-9));
          expect(
            tuft.bottom,
            closeTo((1 - d) * size.height * 0.5 - d * 5, 1e-9),
          );
          expect(tuft.opacity, closeTo(math.min(1, 0.55 + 0.45 * d), 1e-9));
          expect(tuft.blur, closeTo(d <= 0.82 ? (1 - d) * 1.5 : 0, 1e-9));
          expect(tuft.swayDegrees, 4);
          expect(tuft.swayPeriod, inInclusiveRange(4, 7));
          expect(tuft.variant, inInclusiveRange(0, 2));
        }
      }
      if (count >= 20) {
        expect(
          desktop.tufts.where((MeadowTuft tuft) => tuft.depth < 0.5),
          isNotEmpty,
        );
      }
    }
  });

  test('everything is painted back to front', () {
    final List<MeadowItem> items = layoutMeadowByDepth(
      blooms: _blooms(40),
      sprouts: const <String>['2026-06-01', '2026-06-02'],
      size: card,
      seed: 7,
    ).items;
    for (int i = 1; i < items.length; i++) {
      expect(items[i].depth, greaterThanOrEqualTo(items[i - 1].depth));
    }
  });

  test('is deterministic for the same seed, plants and size', () {
    MeadowLayout lay(int seed) => layoutMeadowByDepth(
      blooms: _blooms(24),
      sprouts: const <String>['2026-02-03'],
      size: card,
      seed: seed,
    );
    expect(lay(2026), lay(2026));
    expect(lay(2026), isNot(lay(2027)));
  });

  test('keeps every planted flower for the mood that produced it', () {
    final List<GardenBloomData> blooms = _blooms(10);
    final List<FlowerKind> expected =
        blooms.map((GardenBloomData b) => b.mood.flower).toList()
          ..sort((FlowerKind a, FlowerKind b) => a.index.compareTo(b.index));
    final List<FlowerKind> actual =
        layoutMeadowByDepth(
            blooms: blooms,
            size: card,
            seed: 7,
          ).plants.map((MeadowPlant p) => p.kind).toList()
          ..sort((FlowerKind a, FlowerKind b) => a.index.compareTo(b.index));
    expect(actual, expected);
  });

  test('sprouts are placed like blooms at the sprout size', () {
    final List<MeadowPlant> sprouts = layoutMeadowByDepth(
      blooms: _blooms(4),
      sprouts: const <String>['2026-05-01', '2026-05-02'],
      size: card,
      seed: 3,
    ).plants.where((MeadowPlant plant) => plant.isSprout).toList();
    expect(sprouts.map((MeadowPlant p) => p.date).toSet(), <String>{
      '2026-05-01',
      '2026-05-02',
    });
    for (final MeadowPlant sprout in sprouts) {
      expect(
        sprout.width,
        closeTo(54 * (0.4 + 0.9 * sprout.depth) * sproutSizeFactor, 1e-9),
      );
      expect(sprout.height, closeTo(sprout.width * sproutRatio, 1e-9));
    }
  });

  test('a degenerate card lays out nothing', () {
    expect(
      layoutMeadowByDepth(blooms: _blooms(3), size: Size.zero, seed: 1).items,
      isEmpty,
    );
  });
}
