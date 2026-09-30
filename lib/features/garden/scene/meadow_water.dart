import 'dart:math' as math;
import 'dart:ui';

import 'package:field_notes/features/garden/model/meadow_random.dart';
import 'package:field_notes/features/garden/scene/meadow_world.dart';

const double meadowMouthDepth = 3.62;
const double meadowStreamEnd = meadowMouthDepth + 0.45;

const int _streamSamples = 90;
const int _lakePoints = 90;
const double _lakeReach = 1.12;
const double _lakeTopWindow = 26;
const double _noLakeTop = 9999;
const double _dry = 9;

double _tanh(double v) {
  if (v > 20) {
    return 1;
  }
  if (v < -20) {
    return -1;
  }
  final double e = math.exp(2 * v);
  return (e - 1) / (e + 1);
}

double _centreAt(
  double z, {
  required double drift,
  required double bendAmplitude,
  required double wiggleAmplitude,
  required double bendPhase,
  required double wigglePhase,
}) {
  final double v =
      drift +
      bendAmplitude * math.sin(z * 1.15 + bendPhase) +
      wiggleAmplitude * math.sin(z * 2.7 + wigglePhase);
  final double limit = 0.62 * z;
  return limit * _tanh(v / limit);
}

Offset _project(double x, double z) {
  final MeadowPoint p = meadowProject(x, z);
  return Offset(p.x, p.y);
}

class MeadowStreamSample {
  const MeadowStreamSample({
    required this.point,
    required this.scale,
    required this.depth,
    required this.halfWidth,
  });

  final Offset point;
  final double scale;
  final double depth;
  final double halfWidth;
}

class MeadowWaterCourse {
  const MeadowWaterCourse({
    required this.drift,
    required this.bendAmplitude,
    required this.wiggleAmplitude,
    required this.bendPhase,
    required this.wigglePhase,
    required this.lakeCentreX,
    required this.lakeCentreDepth,
    required this.lakeRadiusX,
    required this.lakeRadiusDepth,
    required this.lakeThirdPhase,
    required this.lakeFifthPhase,
    required this.edgePhases,
    required this.lakeOutline,
  });

  final double drift;
  final double bendAmplitude;
  final double wiggleAmplitude;
  final double bendPhase;
  final double wigglePhase;
  final double lakeCentreX;
  final double lakeCentreDepth;
  final double lakeRadiusX;
  final double lakeRadiusDepth;
  final double lakeThirdPhase;
  final double lakeFifthPhase;
  final List<double> edgePhases;
  final List<Offset> lakeOutline;

  double streamCentre(double z) => _centreAt(
    z,
    drift: drift,
    bendAmplitude: bendAmplitude,
    wiggleAmplitude: wiggleAmplitude,
    bendPhase: bendPhase,
    wigglePhase: wigglePhase,
  );

  double halfWidth(double z) =>
      0.066 +
      0.012 * math.sin(z * 3.1 + wigglePhase) +
      0.17 * math.exp(-math.max(0, meadowMouthDepth + 0.3 - z) * 2.6);

  double leftWidth(double z) =>
      halfWidth(z) *
      (1 +
          0.2 * math.sin(z * 7.3 + edgePhases[0]) +
          0.1 * math.sin(z * 19 + edgePhases[1]));

  double rightWidth(double z) =>
      halfWidth(z) *
      (1 +
          0.2 * math.sin(z * 6.1 + edgePhases[2]) +
          0.1 * math.sin(z * 17 + edgePhases[3]));

  double sideWidth(double z, int side) =>
      side < 0 ? leftWidth(z) : rightWidth(z);

  double bank(double z, int side) =>
      0.016 +
      0.02 *
          (0.5 +
              0.5 *
                  math.sin(
                    z * 11 + (side < 0 ? edgePhases[1] : edgePhases[3]),
                  )) +
      0.01 * math.sin(z * 29 + (side < 0 ? edgePhases[2] : edgePhases[0]));

  double distanceToStream(double x, double z) {
    if (z >= meadowStreamEnd) {
      return _dry;
    }
    final double c = streamCentre(z);
    return x < c ? (c - x) - leftWidth(z) : (x - c) - rightWidth(z);
  }

  bool inStream(double x, double z, double margin) =>
      distanceToStream(x, z) < margin;

  bool inLake(double x, double z) {
    final double dx = (x - lakeCentreX) / lakeRadiusX;
    final double dz = (z - lakeCentreDepth) / lakeRadiusDepth;
    return dx * dx + dz * dz < _lakeReach;
  }

  double lakeTopAt(double x) {
    double top = _noLakeTop;
    for (final Offset q in lakeOutline) {
      if ((q.dx - x).abs() < _lakeTopWindow && q.dy < top) {
        top = q.dy;
      }
    }
    return top;
  }
}

class MeadowWater extends MeadowWaterCourse {
  const MeadowWater._({
    required super.drift,
    required super.bendAmplitude,
    required super.wiggleAmplitude,
    required super.bendPhase,
    required super.wigglePhase,
    required super.lakeCentreX,
    required super.lakeCentreDepth,
    required super.lakeRadiusX,
    required super.lakeRadiusDepth,
    required super.lakeThirdPhase,
    required super.lakeFifthPhase,
    required super.edgePhases,
    required super.lakeOutline,
    required this.lakeFarY,
    required this.lakeNearY,
    required this.lakeLeftX,
    required this.lakeRightX,
    required this.edgeLeft,
    required this.edgeRight,
    required this.centreSamples,
    required this.bankLeft,
    required this.bankRight,
    required this.outerLeft,
    required this.outerRight,
    required this.innerLeft,
    required this.innerRight,
    required this.halfLeft,
    required this.halfRight,
  });

  static MeadowWater build(MeadowRandom random) {
    final double bendAmplitude = random.between(0.28, 0.45);
    final double wiggleAmplitude = random.between(0.1, 0.18);
    final double bendPhase = random.between(0, 6.28);
    final double wigglePhase = random.between(0, 6.28);
    final double drift = random.between(-0.15, 0.15);
    final double lakeRadiusDepth = random.between(2.0, 2.6);
    final double lakeCentreDepth = meadowMouthDepth + lakeRadiusDepth;
    final double lakeRadiusX = random.between(3.2, 4.4);
    final double mouthCentre = _centreAt(
      meadowMouthDepth,
      drift: drift,
      bendAmplitude: bendAmplitude,
      wiggleAmplitude: wiggleAmplitude,
      bendPhase: bendPhase,
      wigglePhase: wigglePhase,
    );
    final double lakeCentreX = mouthCentre * 0.4 + random.between(-0.4, 0.4);
    final double lakeThirdPhase = random.between(0, 6.28);
    final double lakeFifthPhase = random.between(0, 6.28);
    final List<Offset> lakeOutline = List<Offset>.unmodifiable(
      List<Offset>.generate(_lakePoints, (int i) {
        final double th = i / _lakePoints * math.pi * 2;
        final double k =
            1 +
            0.07 * math.sin(3 * th + lakeThirdPhase) +
            0.04 * math.sin(5 * th + lakeFifthPhase);
        return _project(
          lakeCentreX + lakeRadiusX * math.cos(th) * k,
          lakeCentreDepth + lakeRadiusDepth * math.sin(th) * k,
        );
      }),
    );
    final List<double> edgePhases = List<double>.unmodifiable(<double>[
      for (int i = 0; i < 4; i++) random.between(0, 6),
    ]);
    final MeadowWaterCourse course = MeadowWaterCourse(
      drift: drift,
      bendAmplitude: bendAmplitude,
      wiggleAmplitude: wiggleAmplitude,
      bendPhase: bendPhase,
      wigglePhase: wigglePhase,
      lakeCentreX: lakeCentreX,
      lakeCentreDepth: lakeCentreDepth,
      lakeRadiusX: lakeRadiusX,
      lakeRadiusDepth: lakeRadiusDepth,
      lakeThirdPhase: lakeThirdPhase,
      lakeFifthPhase: lakeFifthPhase,
      edgePhases: edgePhases,
      lakeOutline: lakeOutline,
    );
    final double far = 1 / (meadowMouthDepth + 0.5);
    final List<double> depths = List<double>.generate(
      _streamSamples + 1,
      (int i) => 1 / (far + (1 / 0.8 - far) * i / _streamSamples),
    );
    List<Offset> line(double Function(double z) x) =>
        List<Offset>.unmodifiable(depths.map((double z) => _project(x(z), z)));
    double c(double z) => course.streamCentre(z);
    double l(double z) => course.leftWidth(z);
    double r(double z) => course.rightWidth(z);
    return MeadowWater._(
      drift: drift,
      bendAmplitude: bendAmplitude,
      wiggleAmplitude: wiggleAmplitude,
      bendPhase: bendPhase,
      wigglePhase: wigglePhase,
      lakeCentreX: lakeCentreX,
      lakeCentreDepth: lakeCentreDepth,
      lakeRadiusX: lakeRadiusX,
      lakeRadiusDepth: lakeRadiusDepth,
      lakeThirdPhase: lakeThirdPhase,
      lakeFifthPhase: lakeFifthPhase,
      edgePhases: edgePhases,
      lakeOutline: lakeOutline,
      lakeFarY: lakeOutline.map((Offset q) => q.dy).reduce(math.min),
      lakeNearY: lakeOutline.map((Offset q) => q.dy).reduce(math.max),
      lakeLeftX: lakeOutline.map((Offset q) => q.dx).reduce(math.min),
      lakeRightX: lakeOutline.map((Offset q) => q.dx).reduce(math.max),
      edgeLeft: line((double z) => c(z) - l(z)),
      edgeRight: line((double z) => c(z) + r(z)),
      centreSamples: List<MeadowStreamSample>.unmodifiable(
        depths.map((double z) {
          final MeadowPoint p = meadowProject(c(z), z);
          return MeadowStreamSample(
            point: Offset(p.x, p.y),
            scale: p.scale,
            depth: z,
            halfWidth: (l(z) + r(z)) / 2,
          );
        }),
      ),
      bankLeft: line((double z) => c(z) - l(z) - course.bank(z, -1)),
      bankRight: line((double z) => c(z) + r(z) + course.bank(z, 1)),
      outerLeft: line((double z) => c(z) - l(z) - course.bank(z, -1) * 2.6),
      outerRight: line((double z) => c(z) + r(z) + course.bank(z, 1) * 2.6),
      innerLeft: line((double z) => c(z) - l(z) * 0.42),
      innerRight: line((double z) => c(z) + r(z) * 0.42),
      halfLeft: line((double z) => c(z) - l(z) * 0.74),
      halfRight: line((double z) => c(z) + r(z) * 0.74),
    );
  }

  final double lakeFarY;
  final double lakeNearY;
  final double lakeLeftX;
  final double lakeRightX;
  final List<Offset> edgeLeft;
  final List<Offset> edgeRight;
  final List<MeadowStreamSample> centreSamples;
  final List<Offset> bankLeft;
  final List<Offset> bankRight;
  final List<Offset> outerLeft;
  final List<Offset> outerRight;
  final List<Offset> innerLeft;
  final List<Offset> innerRight;
  final List<Offset> halfLeft;
  final List<Offset> halfRight;
}
