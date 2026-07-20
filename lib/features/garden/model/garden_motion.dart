const int defaultMaxAnimatedBlooms = 140;

enum GardenMotionProfile { full, reduced }

GardenMotionProfile resolveGardenMotion({
  required bool reduceMotion,
  required int bloomCount,
  int maxAnimatedBlooms = defaultMaxAnimatedBlooms,
}) {
  if (reduceMotion || bloomCount > maxAnimatedBlooms) {
    return GardenMotionProfile.reduced;
  }
  return GardenMotionProfile.full;
}
