const int defaultMaxAnimatedBlooms = 366;

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
