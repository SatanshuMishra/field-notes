import 'dart:math' as math;
import 'dart:ui';

const double meadowWorldWidth = 1400;
const double meadowWorldHeight = 640;
const double meadowHorizonY = 286;
const double meadowFocal = 324;
const double meadowSpread = 700;
const double meadowNearScale = 0.72;

const double _farDepth = 3.5;
const double _nearDepth = 1.03;

double meadowDepthOf(double u) {
  return 1 / (1 / _farDepth + (1 / _nearDepth - 1 / _farDepth) * u);
}

double meadowProgressOfDepth(double z) {
  return (1 / z - 1 / _farDepth) / (1 / _nearDepth - 1 / _farDepth);
}

double meadowDepthAtRow(double y) {
  return meadowFocal / math.max(0.5, y - meadowHorizonY);
}

class MeadowPoint {
  const MeadowPoint({required this.x, required this.y, required this.scale});

  final double x;
  final double y;
  final double scale;
}

MeadowPoint meadowProject(double x, double z) {
  return MeadowPoint(
    x: meadowSpread + x * meadowSpread / z,
    y: meadowHorizonY + meadowFocal / z,
    scale: meadowNearScale / z,
  );
}

double meadowDayProgress(int dayIndex, int daysInYear) {
  return dayIndex / (daysInYear - 1);
}

class MeadowViewport {
  const MeadowViewport({
    required this.scale,
    required this.offset,
    required this.pan,
  });

  final double scale;
  final Offset offset;
  final double pan;

  static MeadowViewport resolve({
    required Size box,
    required bool cover,
    double? pan,
    required double focusX,
  }) {
    if (!cover) {
      return MeadowViewport(
        scale: box.width / meadowWorldWidth,
        offset: Offset.zero,
        pan: 0,
      );
    }
    final double scale = math.max(
      box.width / meadowWorldWidth,
      box.height / meadowWorldHeight,
    );
    final double visible = box.width / scale;
    final double resolvedPan = (pan ?? focusX - visible / 2).clamp(
      0.0,
      math.max(0.0, meadowWorldWidth - visible),
    );
    return MeadowViewport(
      scale: scale,
      offset: Offset(
        -resolvedPan * scale,
        (box.height - meadowWorldHeight * scale) / 2,
      ),
      pan: resolvedPan,
    );
  }

  Offset toWorld(Offset local) => (local - offset) / scale;

  Offset toLocal(Offset world) => world * scale + offset;
}
