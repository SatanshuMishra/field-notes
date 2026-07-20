import 'dart:ui';

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/garden/model/garden_data.dart';
import 'package:field_notes/features/garden/model/meadow_layout.dart';
import 'package:flutter_test/flutter_test.dart';

List<GardenBloomData> _blooms(int n) => List<GardenBloomData>.generate(
      n,
      (int i) => GardenBloomData(
        date: '2026-01-${(i + 1).toString().padLeft(2, '0')}',
        mood: moodOrder[i % moodOrder.length],
      ),
    );

void main() {
  const Size size = Size(400, 300);

  test('is deterministic for the same seed, blooms and size', () {
    final List<PlantedBloom> a =
        layoutMeadow(blooms: _blooms(12), size: size, seed: 2026);
    final List<PlantedBloom> b =
        layoutMeadow(blooms: _blooms(12), size: size, seed: 2026);
    expect(a, b);
  });

  test('a different seed produces a different arrangement', () {
    final List<PlantedBloom> a =
        layoutMeadow(blooms: _blooms(12), size: size, seed: 2026);
    final List<PlantedBloom> b =
        layoutMeadow(blooms: _blooms(12), size: size, seed: 2027);
    expect(a, isNot(b));
  });

  test('plants one bloom per data item inside the soil band and canvas', () {
    final List<PlantedBloom> planted =
        layoutMeadow(blooms: _blooms(20), size: size, seed: 1);
    expect(planted.length, 20);
    for (final PlantedBloom p in planted) {
      expect(p.dx, inInclusiveRange(0, size.width));
      expect(
        p.baseY,
        inInclusiveRange(size.height * soilLineFraction, size.height),
      );
      expect(p.size, greaterThan(0));
    }
  });

  test('returns back-to-front paint order (ascending baseY)', () {
    final List<PlantedBloom> planted =
        layoutMeadow(blooms: _blooms(20), size: size, seed: 1);
    for (int i = 1; i < planted.length; i++) {
      expect(planted[i].baseY, greaterThanOrEqualTo(planted[i - 1].baseY));
    }
  });

  test('keeps every planted flower for the mood that produced it', () {
    final List<GardenBloomData> blooms = _blooms(10);
    final List<PlantedBloom> planted =
        layoutMeadow(blooms: blooms, size: size, seed: 7);
    final List<FlowerKind> expected = blooms
        .map((GardenBloomData b) => b.mood.flower)
        .toList()
      ..sort((FlowerKind a, FlowerKind b) => a.index.compareTo(b.index));
    final List<FlowerKind> actual = planted
        .map((PlantedBloom p) => p.kind)
        .toList()
      ..sort((FlowerKind a, FlowerKind b) => a.index.compareTo(b.index));
    expect(actual, expected);
  });

  test('is empty for no blooms or a degenerate size', () {
    expect(
      layoutMeadow(blooms: const <GardenBloomData>[], size: size, seed: 1),
      isEmpty,
    );
    expect(
      layoutMeadow(blooms: _blooms(3), size: Size.zero, seed: 1),
      isEmpty,
    );
  });
}
