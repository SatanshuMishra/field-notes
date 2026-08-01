import 'package:flutter/painting.dart';

import 'package:field_notes/domain/mood/flower_kind.dart';

import 'bloom_part.dart';
import 'flower_palette.dart';
import 'garden_plant_geometry.dart';

class GardenPlantSpec {
  const GardenPlantSpec({
    required this.kind,
    required this.viewBoxHeight,
    required this.parts,
    required this.strokeColor,
    required this.strokeWidth,
  });

  static const double viewBoxWidth = 100;

  final FlowerKind kind;
  final double viewBoxHeight;
  final List<BloomPart> parts;
  final Color strokeColor;
  final double strokeWidth;

  double get ratio => viewBoxHeight / viewBoxWidth;
}

GardenPlantSpec gardenPlantSpecFor(FlowerKind kind) =>
    _gardenPlants[kind] ?? _peonyPlant;

final GardenPlantSpec _peonyPlant = GardenPlantSpec(
  kind: FlowerKind.peony,
  viewBoxHeight: 190,
  parts: peonyPlantParts,
  strokeColor: FlowerColors.peonyStroke,
  strokeWidth: 2.3,
);

final Map<FlowerKind, GardenPlantSpec> _gardenPlants =
    <FlowerKind, GardenPlantSpec>{
  FlowerKind.peony: _peonyPlant,
  FlowerKind.sunflower: GardenPlantSpec(
    kind: FlowerKind.sunflower,
    viewBoxHeight: 240,
    parts: sunflowerPlantParts,
    strokeColor: FlowerColors.sunflowerStroke,
    strokeWidth: 1.3,
  ),
  FlowerKind.poppy: GardenPlantSpec(
    kind: FlowerKind.poppy,
    viewBoxHeight: 236,
    parts: poppyPlantParts,
    strokeColor: FlowerColors.poppyStroke,
    strokeWidth: 2.2,
  ),
  FlowerKind.redSpiderLily: GardenPlantSpec(
    kind: FlowerKind.redSpiderLily,
    viewBoxHeight: 214,
    parts: spiderLilyPlantParts,
    strokeColor: FlowerColors.spiderLilyStroke,
    strokeWidth: 2.6,
  ),
  FlowerKind.daffodil: GardenPlantSpec(
    kind: FlowerKind.daffodil,
    viewBoxHeight: 214,
    parts: daffodilPlantParts,
    strokeColor: FlowerColors.daffodilStroke,
    strokeWidth: 1.5,
  ),
  FlowerKind.aster: GardenPlantSpec(
    kind: FlowerKind.aster,
    viewBoxHeight: 210,
    parts: asterPlantParts,
    strokeColor: FlowerColors.asterStroke,
    strokeWidth: 0.9,
  ),
  FlowerKind.rose: GardenPlantSpec(
    kind: FlowerKind.rose,
    viewBoxHeight: 205,
    parts: rosePlantParts,
    strokeColor: FlowerColors.roseStroke,
    strokeWidth: 2.4,
  ),
  FlowerKind.bleedingHeart: GardenPlantSpec(
    kind: FlowerKind.bleedingHeart,
    viewBoxHeight: 200,
    parts: bleedingHeartPlantParts,
    strokeColor: FlowerColors.bleedingHeartStroke,
    strokeWidth: 1.6,
  ),
  FlowerKind.chrysanthemum: GardenPlantSpec(
    kind: FlowerKind.chrysanthemum,
    viewBoxHeight: 196,
    parts: chrysanthemumPlantParts,
    strokeColor: FlowerColors.chrysanthemumStroke,
    strokeWidth: 0.8,
  ),
  FlowerKind.lavender: GardenPlantSpec(
    kind: FlowerKind.lavender,
    viewBoxHeight: 190,
    parts: lavenderPlantParts,
    strokeColor: FlowerColors.lavenderStroke,
    strokeWidth: 1,
  ),
};
