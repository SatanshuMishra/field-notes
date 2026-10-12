const Duration voiceLevelInterval = Duration(milliseconds: 60);
const double voiceLevelFloorDbfs = -50;
const double voiceLevelCeilingDbfs = -10;

double voiceLevelFromDbfs(double dbfs) {
  if (!dbfs.isFinite) {
    return 0;
  }
  final double level =
      (dbfs - voiceLevelFloorDbfs) /
      (voiceLevelCeilingDbfs - voiceLevelFloorDbfs);
  return level.clamp(0.0, 1.0);
}
