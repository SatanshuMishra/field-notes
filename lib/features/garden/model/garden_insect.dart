import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

enum GardenInsectKind { butterfly, bee }

class GardenInsect {
  const GardenInsect({
    required this.kind,
    required this.phase,
    required this.yBand,
    required this.speed,
    required this.amplitude,
  });

  final GardenInsectKind kind;
  final double phase;
  final double yBand;
  final double speed;
  final double amplitude;
}

const List<GardenInsect> defaultGardenInsects = <GardenInsect>[
  GardenInsect(
    kind: GardenInsectKind.butterfly,
    phase: 0.0,
    yBand: 0.28,
    speed: 1.0,
    amplitude: 0.10,
  ),
  GardenInsect(
    kind: GardenInsectKind.butterfly,
    phase: 0.55,
    yBand: 0.40,
    speed: 0.8,
    amplitude: 0.12,
  ),
  GardenInsect(
    kind: GardenInsectKind.bee,
    phase: 0.30,
    yBand: 0.50,
    speed: 1.4,
    amplitude: 0.08,
  ),
];

Offset insectOffset(
  GardenInsect insect,
  double t,
  Size size,
  double skyHeight,
) {
  if (size.width <= 0 || size.height <= 0 || skyHeight <= 0) {
    return Offset.zero;
  }
  final double u = (t * insect.speed + insect.phase) % 1.0;
  final double x = (size.width * u).clamp(0.0, size.width);
  final double wobble =
      math.sin(2 * math.pi * (u * 2 + insect.phase)) * insect.amplitude;
  final double y = (skyHeight * (insect.yBand + wobble)).clamp(0.0, skyHeight);
  return Offset(x, y);
}
