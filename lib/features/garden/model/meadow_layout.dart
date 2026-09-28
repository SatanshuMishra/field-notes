import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:field_notes/domain/mood/flower_kind.dart';

import 'garden_data.dart';

const double soilLineFraction = 0.60;

class PlantedBloom {
  const PlantedBloom({
    required this.kind,
    required this.dx,
    required this.baseY,
    required this.size,
    required this.swayPhase,
    required this.swayAmplitude,
    this.date = '',
    this.isSprout = false,
  });

  final FlowerKind kind;
  final double dx;
  final double baseY;
  final double size;
  final double swayPhase;
  final double swayAmplitude;
  final String date;
  final bool isSprout;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlantedBloom &&
          runtimeType == other.runtimeType &&
          kind == other.kind &&
          dx == other.dx &&
          baseY == other.baseY &&
          size == other.size &&
          swayPhase == other.swayPhase &&
          swayAmplitude == other.swayAmplitude &&
          date == other.date &&
          isSprout == other.isSprout;

  @override
  int get hashCode => Object.hash(
    kind,
    dx,
    baseY,
    size,
    swayPhase,
    swayAmplitude,
    date,
    isSprout,
  );

  @override
  String toString() =>
      'PlantedBloom(kind: $kind, dx: $dx, baseY: $baseY, size: $size, '
      'swayPhase: $swayPhase, swayAmplitude: $swayAmplitude, date: $date, '
      'isSprout: $isSprout)';
}

const double sproutSizeFactor = 0.45;

class _MeadowSeed {
  const _MeadowSeed({
    required this.date,
    required this.kind,
    required this.isSprout,
  });

  final String date;
  final FlowerKind kind;
  final bool isSprout;
}

List<_MeadowSeed> _seedsInDateOrder(
  List<GardenBloomData> blooms,
  List<String> sprouts,
) {
  final List<_MeadowSeed> seeds = <_MeadowSeed>[
    for (final GardenBloomData bloom in blooms)
      _MeadowSeed(date: bloom.date, kind: bloom.mood.flower, isSprout: false),
    for (final String date in sprouts)
      _MeadowSeed(date: date, kind: FlowerKind.daffodil, isSprout: true),
  ];
  if (sprouts.isEmpty) {
    return seeds;
  }
  final List<(int, _MeadowSeed)> ordered = seeds.indexed.toList()
    ..sort(((int, _MeadowSeed) a, (int, _MeadowSeed) b) {
      final int byDate = a.$2.date.compareTo(b.$2.date);
      return byDate != 0 ? byDate : a.$1.compareTo(b.$1);
    });
  return <_MeadowSeed>[
    for (final (int, _MeadowSeed) entry in ordered) entry.$2,
  ];
}

List<PlantedBloom> layoutMeadow({
  required List<GardenBloomData> blooms,
  required Size size,
  required int seed,
  int rows = 4,
  List<String> sprouts = const <String>[],
}) {
  final List<_MeadowSeed> seeds = _seedsInDateOrder(blooms, sprouts);
  if (seeds.isEmpty || size.width <= 0 || size.height <= 0 || rows <= 0) {
    return const <PlantedBloom>[];
  }
  final math.Random rng = math.Random(seed);
  final double soilTop = size.height * soilLineFraction;
  final double soilBottom = size.height * 0.96;
  final double rowGap = (soilBottom - soilTop) / rows;
  final List<PlantedBloom> planted = <PlantedBloom>[];
  for (int i = 0; i < seeds.length; i++) {
    final _MeadowSeed plant = seeds[i];
    final int row = i % rows;
    final double jitterY = (rng.nextDouble() - 0.5) * rowGap * 0.35;
    final double baseY =
        (soilTop + rowGap * (row + 0.5) + jitterY).clamp(soilTop, size.height);
    final double dx =
        (size.width * (0.04 + rng.nextDouble() * 0.92)).clamp(0.0, size.width);
    final double depth = row / rows;
    final double bloomSize =
        size.height *
        (0.16 + rng.nextDouble() * 0.05) *
        (1 + depth * 0.35) *
        (plant.isSprout ? sproutSizeFactor : 1);
    final double swayPhase = rng.nextDouble() * 2 * math.pi;
    final double swayAmplitude = 0.02 + rng.nextDouble() * 0.03;
    planted.add(
      PlantedBloom(
        kind: plant.kind,
        dx: dx,
        baseY: baseY,
        size: bloomSize,
        swayPhase: swayPhase,
        swayAmplitude: swayAmplitude,
        date: plant.date,
        isSprout: plant.isSprout,
      ),
    );
  }
  planted.sort((PlantedBloom a, PlantedBloom b) => a.baseY.compareTo(b.baseY));
  return planted;
}
