import 'package:flutter/painting.dart';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/mood/flower_kind.dart';

import 'bloom_geometry.dart';
import 'bloom_part.dart';
import 'bloom_style.dart';
import 'flower_palette.dart';

class ProceduralBloom {
  const ProceduralBloom({
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

class FlowerSpec {
  const FlowerSpec.parts({
    required this.kind,
    required this.parts,
    required this.strokeColor,
    required this.strokeWidth,
  })  : style = BloomStyle.partList,
        procedural = null;

  const FlowerSpec.procedural({
    required this.kind,
    required this.style,
    required this.procedural,
    required this.strokeColor,
    required this.strokeWidth,
  }) : parts = null;

  final FlowerKind kind;
  final BloomStyle style;
  final List<BloomPart>? parts;
  final ProceduralBloom? procedural;
  final Color strokeColor;
  final double strokeWidth;
}

FlowerSpec flowerSpecFor(FlowerKind kind) => switch (kind) {
      FlowerKind.peony => const FlowerSpec.parts(
          kind: FlowerKind.peony,
          parts: peonyParts,
          strokeColor: FlowerColors.peonyStroke,
          strokeWidth: 1.4,
        ),
      FlowerKind.rose => const FlowerSpec.parts(
          kind: FlowerKind.rose,
          parts: roseParts,
          strokeColor: FlowerColors.roseStroke,
          strokeWidth: 1.3,
        ),
      FlowerKind.sunflower => const FlowerSpec.parts(
          kind: FlowerKind.sunflower,
          parts: sunflowerParts,
          strokeColor: FlowerColors.sunflowerStroke,
          strokeWidth: 1.0,
        ),
      FlowerKind.poppy => const FlowerSpec.parts(
          kind: FlowerKind.poppy,
          parts: poppyParts,
          strokeColor: FlowerColors.poppyStroke,
          strokeWidth: 1.3,
        ),
      FlowerKind.chrysanthemum => const FlowerSpec.procedural(
          kind: FlowerKind.chrysanthemum,
          style: BloomStyle.rayPetals,
          procedural: ProceduralBloom(
            petalCount: 20,
            petalColor: FlowerColors.chrysanthemumPetal,
            petalShade: FlowerColors.chrysanthemumShade,
            centerColor: FlowerColors.chrysanthemumCenter,
            centerRadius: 0.12,
            petalLength: 0.32,
            petalWidth: 0.08,
          ),
          strokeColor: FlowerColors.chrysanthemumStroke,
          strokeWidth: 0.8,
        ),
      FlowerKind.daffodil => const FlowerSpec.procedural(
          kind: FlowerKind.daffodil,
          style: BloomStyle.rayPetals,
          procedural: ProceduralBloom(
            petalCount: 6,
            petalColor: FlowerColors.daffodilPetal,
            petalShade: FlowerColors.daffodilShade,
            centerColor: FlowerColors.daffodilCenter,
            centerRadius: 0.14,
            petalLength: 0.34,
            petalWidth: 0.16,
          ),
          strokeColor: FlowerColors.daffodilStroke,
          strokeWidth: 1.2,
        ),
      FlowerKind.lavender => const FlowerSpec.procedural(
          kind: FlowerKind.lavender,
          style: BloomStyle.spike,
          procedural: ProceduralBloom(
            petalCount: 9,
            petalColor: FlowerColors.lavenderPetal,
            petalShade: FlowerColors.lavenderShade,
            centerColor: FlowerColors.lavenderCenter,
            centerRadius: 0.05,
            petalLength: 0.42,
            petalWidth: 0.12,
          ),
          strokeColor: FlowerColors.lavenderStroke,
          strokeWidth: 1.0,
        ),
      FlowerKind.aster => const FlowerSpec.procedural(
          kind: FlowerKind.aster,
          style: BloomStyle.rayPetals,
          procedural: ProceduralBloom(
            petalCount: 22,
            petalColor: FlowerColors.asterPetal,
            petalShade: FlowerColors.asterShade,
            centerColor: FlowerColors.asterCenter,
            centerRadius: 0.10,
            petalLength: 0.34,
            petalWidth: 0.06,
          ),
          strokeColor: FlowerColors.asterStroke,
          strokeWidth: 0.9,
        ),
      FlowerKind.bleedingHeart => const FlowerSpec.procedural(
          kind: FlowerKind.bleedingHeart,
          style: BloomStyle.heartPendants,
          procedural: ProceduralBloom(
            petalCount: 4,
            petalColor: FlowerColors.bleedingHeartPetal,
            petalShade: FlowerColors.bleedingHeartShade,
            centerColor: FlowerColors.bleedingHeartCenter,
            centerRadius: 0.02,
            petalLength: 0.20,
            petalWidth: 0.16,
          ),
          strokeColor: FlowerColors.bleedingHeartStroke,
          strokeWidth: 1.3,
        ),
      FlowerKind.redSpiderLily => const FlowerSpec.procedural(
          kind: FlowerKind.redSpiderLily,
          style: BloomStyle.spiderPetals,
          procedural: ProceduralBloom(
            petalCount: 8,
            petalColor: FlowerColors.redSpiderLilyPetal,
            petalShade: FlowerColors.redSpiderLilyShade,
            centerColor: FlowerColors.redSpiderLilyCenter,
            centerRadius: 0.06,
            petalLength: 0.40,
            petalWidth: 0.12,
          ),
          strokeColor: FlowerColors.spiderLilyStroke,
          strokeWidth: 1.8,
        ),
      FlowerKind.wiltingRose => const FlowerSpec.procedural(
          kind: FlowerKind.wiltingRose,
          style: BloomStyle.roundPetals,
          procedural: ProceduralBloom(
            petalCount: 6,
            petalColor: FlowerColors.wiltingRosePetal,
            petalShade: FlowerColors.wiltingRoseShade,
            centerColor: FlowerColors.wiltingRoseCenter,
            centerRadius: 0.09,
            petalLength: 0.26,
            petalWidth: 0.24,
            droop: true,
          ),
          strokeColor: FlowerColors.wiltingRoseStroke,
          strokeWidth: 1.3,
        ),
      FlowerKind.thistle => const FlowerSpec.procedural(
          kind: FlowerKind.thistle,
          style: BloomStyle.puff,
          procedural: ProceduralBloom(
            petalCount: 11,
            petalColor: FlowerColors.thistlePetal,
            petalShade: FlowerColors.thistleShade,
            centerColor: FlowerColors.thistleCenter,
            centerRadius: 0.12,
            petalLength: 0.26,
            petalWidth: 0.10,
          ),
          strokeColor: FlowerColors.thistleStroke,
          strokeWidth: 1.3,
        ),
    };
