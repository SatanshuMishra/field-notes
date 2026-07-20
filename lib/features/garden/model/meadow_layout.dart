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
  });

  final FlowerKind kind;
  final double dx;
  final double baseY;
  final double size;
  final double swayPhase;
  final double swayAmplitude;

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
          swayAmplitude == other.swayAmplitude;

  @override
  int get hashCode =>
      Object.hash(kind, dx, baseY, size, swayPhase, swayAmplitude);

  @override
  String toString() =>
      'PlantedBloom(kind: $kind, dx: $dx, baseY: $baseY, size: $size, '
      'swayPhase: $swayPhase, swayAmplitude: $swayAmplitude)';
}

List<PlantedBloom> layoutMeadow({
  required List<GardenBloomData> blooms,
  required Size size,
  required int seed,
  int rows = 4,
}) {
  if (blooms.isEmpty || size.width <= 0 || size.height <= 0 || rows <= 0) {
    return const <PlantedBloom>[];
  }
  final math.Random rng = math.Random(seed);
  final double soilTop = size.height * soilLineFraction;
  final double soilBottom = size.height * 0.96;
  final double rowGap = (soilBottom - soilTop) / rows;
  final List<PlantedBloom> planted = <PlantedBloom>[];
  for (int i = 0; i < blooms.length; i++) {
    final int row = i % rows;
    final double jitterY = (rng.nextDouble() - 0.5) * rowGap * 0.35;
    final double baseY =
        (soilTop + rowGap * (row + 0.5) + jitterY).clamp(soilTop, size.height);
    final double dx =
        (size.width * (0.04 + rng.nextDouble() * 0.92)).clamp(0.0, size.width);
    final double depth = row / rows;
    final double bloomSize =
        size.height * (0.16 + rng.nextDouble() * 0.05) * (1 + depth * 0.35);
    final double swayPhase = rng.nextDouble() * 2 * math.pi;
    final double swayAmplitude = 0.02 + rng.nextDouble() * 0.03;
    planted.add(
      PlantedBloom(
        kind: blooms[i].mood.flower,
        dx: dx,
        baseY: baseY,
        size: bloomSize,
        swayPhase: swayPhase,
        swayAmplitude: swayAmplitude,
      ),
    );
  }
  planted.sort((PlantedBloom a, PlantedBloom b) => a.baseY.compareTo(b.baseY));
  return planted;
}
