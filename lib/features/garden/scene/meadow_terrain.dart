import 'package:field_notes/features/garden/model/meadow_random.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/scene/meadow_forest.dart';
import 'package:field_notes/features/garden/scene/meadow_ground_dressing.dart';
import 'package:field_notes/features/garden/scene/meadow_mountains.dart';
import 'package:field_notes/features/garden/scene/meadow_sky_dressing.dart';
import 'package:field_notes/features/garden/scene/meadow_water.dart';

export 'package:field_notes/features/garden/scene/meadow_forest.dart';
export 'package:field_notes/features/garden/scene/meadow_ground_dressing.dart';
export 'package:field_notes/features/garden/scene/meadow_mountains.dart';
export 'package:field_notes/features/garden/scene/meadow_sky_dressing.dart';
export 'package:field_notes/features/garden/scene/meadow_water.dart';

class MeadowTerrain {
  const MeadowTerrain({
    required this.seed,
    required this.water,
    required this.mountains,
    required this.forest,
    required this.ground,
    required this.sky,
  });

  final int seed;
  final MeadowWater water;
  final MeadowMountains mountains;
  final MeadowForest forest;
  final MeadowGroundDressing ground;
  final MeadowSkyDressing sky;
}

MeadowTerrain buildMeadowTerrain({
  required int seed,
  required MeadowYear year,
}) {
  final MeadowRandom random = MeadowRandom(
    meadowPartSeed(seed, MeadowPart.terrain),
  );
  final MeadowWater water = MeadowWater.build(random);
  final MeadowMountains mountains = MeadowMountains.build(random, water);
  final MeadowForest forest = MeadowForest.build(
    random,
    water: water,
    mountains: mountains,
    year: year,
  );
  final MeadowGroundDressing ground = MeadowGroundDressing.build(
    random,
    water: water,
    mountains: mountains,
  );
  final MeadowSkyDressing sky = MeadowSkyDressing.build(
    random,
    water: water,
    mountains: mountains,
    forest: forest,
    year: year,
  );
  return MeadowTerrain(
    seed: seed,
    water: water,
    mountains: mountains,
    forest: forest,
    ground: ground,
    sky: sky,
  );
}
