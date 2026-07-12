import 'package:flutter/painting.dart';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/mood/flower_kind.dart';

import 'bloom_style.dart';
import 'flower_palette.dart';

class FlowerSpec {
  const FlowerSpec({
    required this.kind,
    required this.style,
    required this.petalCount,
    required this.petalColor,
    required this.petalShade,
    required this.centerColor,
    required this.centerRadius,
    required this.petalLength,
    required this.petalWidth,
    this.droop = false,
    this.stemColor = Palette.gardenStem,
    this.leafColor = Palette.gardenLeaf,
  });

  final FlowerKind kind;
  final BloomStyle style;
  final int petalCount;
  final Color petalColor;
  final Color petalShade;
  final Color centerColor;
  final double centerRadius;
  final double petalLength;
  final double petalWidth;
  final bool droop;
  final Color stemColor;
  final Color leafColor;
}

FlowerSpec flowerSpecFor(FlowerKind kind) => switch (kind) {
      FlowerKind.peony => const FlowerSpec(
          kind: FlowerKind.peony,
          style: BloomStyle.roundPetals,
          petalCount: 12,
          petalColor: FlowerColors.peonyPetal,
          petalShade: FlowerColors.peonyShade,
          centerColor: FlowerColors.peonyCenter,
          centerRadius: 0.12,
          petalLength: 0.32,
          petalWidth: 0.24,
        ),
      FlowerKind.rose => const FlowerSpec(
          kind: FlowerKind.rose,
          style: BloomStyle.roundPetals,
          petalCount: 8,
          petalColor: FlowerColors.rosePetal,
          petalShade: FlowerColors.roseShade,
          centerColor: FlowerColors.roseCenter,
          centerRadius: 0.10,
          petalLength: 0.30,
          petalWidth: 0.26,
        ),
      FlowerKind.sunflower => const FlowerSpec(
          kind: FlowerKind.sunflower,
          style: BloomStyle.rayPetals,
          petalCount: 16,
          petalColor: FlowerColors.sunflowerPetal,
          petalShade: FlowerColors.sunflowerShade,
          centerColor: FlowerColors.sunflowerCenter,
          centerRadius: 0.20,
          petalLength: 0.30,
          petalWidth: 0.10,
        ),
      FlowerKind.chrysanthemum => const FlowerSpec(
          kind: FlowerKind.chrysanthemum,
          style: BloomStyle.rayPetals,
          petalCount: 20,
          petalColor: FlowerColors.chrysanthemumPetal,
          petalShade: FlowerColors.chrysanthemumShade,
          centerColor: FlowerColors.chrysanthemumCenter,
          centerRadius: 0.12,
          petalLength: 0.32,
          petalWidth: 0.08,
        ),
      FlowerKind.daffodil => const FlowerSpec(
          kind: FlowerKind.daffodil,
          style: BloomStyle.rayPetals,
          petalCount: 6,
          petalColor: FlowerColors.daffodilPetal,
          petalShade: FlowerColors.daffodilShade,
          centerColor: FlowerColors.daffodilCenter,
          centerRadius: 0.14,
          petalLength: 0.34,
          petalWidth: 0.16,
        ),
      FlowerKind.lavender => const FlowerSpec(
          kind: FlowerKind.lavender,
          style: BloomStyle.spike,
          petalCount: 9,
          petalColor: FlowerColors.lavenderPetal,
          petalShade: FlowerColors.lavenderShade,
          centerColor: FlowerColors.lavenderCenter,
          centerRadius: 0.05,
          petalLength: 0.42,
          petalWidth: 0.12,
        ),
      FlowerKind.aster => const FlowerSpec(
          kind: FlowerKind.aster,
          style: BloomStyle.rayPetals,
          petalCount: 22,
          petalColor: FlowerColors.asterPetal,
          petalShade: FlowerColors.asterShade,
          centerColor: FlowerColors.asterCenter,
          centerRadius: 0.10,
          petalLength: 0.34,
          petalWidth: 0.06,
        ),
      FlowerKind.poppy => const FlowerSpec(
          kind: FlowerKind.poppy,
          style: BloomStyle.broadPetals,
          petalCount: 4,
          petalColor: FlowerColors.poppyPetal,
          petalShade: FlowerColors.poppyShade,
          centerColor: FlowerColors.poppyCenter,
          centerRadius: 0.14,
          petalLength: 0.32,
          petalWidth: 0.34,
        ),
      FlowerKind.bleedingHeart => const FlowerSpec(
          kind: FlowerKind.bleedingHeart,
          style: BloomStyle.heartPendants,
          petalCount: 4,
          petalColor: FlowerColors.bleedingHeartPetal,
          petalShade: FlowerColors.bleedingHeartShade,
          centerColor: FlowerColors.bleedingHeartCenter,
          centerRadius: 0.02,
          petalLength: 0.20,
          petalWidth: 0.16,
        ),
      FlowerKind.redSpiderLily => const FlowerSpec(
          kind: FlowerKind.redSpiderLily,
          style: BloomStyle.spiderPetals,
          petalCount: 8,
          petalColor: FlowerColors.redSpiderLilyPetal,
          petalShade: FlowerColors.redSpiderLilyShade,
          centerColor: FlowerColors.redSpiderLilyCenter,
          centerRadius: 0.06,
          petalLength: 0.40,
          petalWidth: 0.12,
        ),
      FlowerKind.wiltingRose => const FlowerSpec(
          kind: FlowerKind.wiltingRose,
          style: BloomStyle.roundPetals,
          petalCount: 6,
          petalColor: FlowerColors.wiltingRosePetal,
          petalShade: FlowerColors.wiltingRoseShade,
          centerColor: FlowerColors.wiltingRoseCenter,
          centerRadius: 0.09,
          petalLength: 0.26,
          petalWidth: 0.24,
          droop: true,
        ),
      FlowerKind.thistle => const FlowerSpec(
          kind: FlowerKind.thistle,
          style: BloomStyle.puff,
          petalCount: 11,
          petalColor: FlowerColors.thistlePetal,
          petalShade: FlowerColors.thistleShade,
          centerColor: FlowerColors.thistleCenter,
          centerRadius: 0.12,
          petalLength: 0.26,
          petalWidth: 0.10,
        ),
    };
