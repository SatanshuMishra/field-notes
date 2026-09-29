import 'dart:math' as math;

const double _rad = math.pi / 180;
const double _obliquity = _rad * 23.4397;
const double _sunDistanceKm = 149598000;
const double _sunHorizonAltitude = -0.833;
const int _coarseStepMinutes = 5;
const int _coarseSteps = 432;
const Duration _crossingPrecision = Duration(milliseconds: 500);

enum SkyBody { sun, moon }

class SkyPosition {
  const SkyPosition({required this.azimuth, required this.altitude});

  final double azimuth;
  final double altitude;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SkyPosition &&
          runtimeType == other.runtimeType &&
          azimuth == other.azimuth &&
          altitude == other.altitude;

  @override
  int get hashCode => Object.hash(azimuth, altitude);

  @override
  String toString() => 'SkyPosition(azimuth: $azimuth, altitude: $altitude)';
}

class MoonIllumination {
  const MoonIllumination({required this.fraction, required this.phase});

  final double fraction;
  final double phase;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MoonIllumination &&
          runtimeType == other.runtimeType &&
          fraction == other.fraction &&
          phase == other.phase;

  @override
  int get hashCode => Object.hash(fraction, phase);

  @override
  String toString() => 'MoonIllumination(fraction: $fraction, phase: $phase)';
}

class SkyEvent {
  const SkyEvent({required this.instant, required this.isRise});

  final DateTime instant;
  final bool isRise;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SkyEvent &&
          runtimeType == other.runtimeType &&
          instant == other.instant &&
          isRise == other.isRise;

  @override
  int get hashCode => Object.hash(instant, isRise);

  @override
  String toString() => 'SkyEvent(instant: $instant, isRise: $isRise)';
}

class _Equatorial {
  const _Equatorial({
    required this.rightAscension,
    required this.declination,
    required this.distance,
  });

  final double rightAscension;
  final double declination;
  final double distance;
}

double _daysSinceJ2000(DateTime instant) =>
    instant.millisecondsSinceEpoch / 86400000 - 0.5 + 2440588 - 2451545;

double _rightAscension(double l, double b) => math.atan2(
  math.sin(l) * math.cos(_obliquity) - math.tan(b) * math.sin(_obliquity),
  math.cos(l),
);

double _declination(double l, double b) => math.asin(
  math.sin(b) * math.cos(_obliquity) +
      math.cos(b) * math.sin(_obliquity) * math.sin(l),
);

double _siderealAngle(double d, double lw) =>
    _rad * (280.46061837 + 360.98564736629 * d) - lw;

double _sinDegrees(double degrees) => math.sin(_rad * degrees);

double _cosDegrees(double degrees) => math.cos(_rad * degrees);

_Equatorial _sunCoordinates(double d) {
  final double g = _rad * (357.528 + 0.9856003 * d);
  final double l =
      _rad *
      (280.460 + 0.9856474 * d + 1.915 * math.sin(g) + 0.020 * math.sin(2 * g));
  return _Equatorial(
    rightAscension: _rightAscension(l, 0),
    declination: _declination(l, 0),
    distance: _sunDistanceKm,
  );
}

double _moonParallax(double t) =>
    0.9508 +
    0.0518 * _cosDegrees(135.0 + 477198.87 * t) +
    0.0095 * _cosDegrees(259.3 - 413335.36 * t) +
    0.0078 * _cosDegrees(235.7 + 890534.22 * t) +
    0.0028 * _cosDegrees(269.9 + 954397.74 * t);

_Equatorial _moonCoordinates(double d) {
  final double t = d / 36525;
  final double longitude =
      218.32 +
      481267.881 * t +
      6.29 * _sinDegrees(135.0 + 477198.87 * t) -
      1.27 * _sinDegrees(259.3 - 413335.36 * t) +
      0.66 * _sinDegrees(235.7 + 890534.22 * t) +
      0.21 * _sinDegrees(269.9 + 954397.74 * t) -
      0.19 * _sinDegrees(357.5 + 35999.05 * t) -
      0.11 * _sinDegrees(186.5 + 966404.03 * t);
  final double latitude =
      5.13 * _sinDegrees(93.3 + 483202.02 * t) +
      0.28 * _sinDegrees(228.2 + 960400.89 * t) -
      0.28 * _sinDegrees(318.3 + 6003.15 * t) -
      0.17 * _sinDegrees(217.6 - 407332.21 * t);
  final double l = _rad * longitude;
  final double b = _rad * latitude;
  return _Equatorial(
    rightAscension: _rightAscension(l, b),
    declination: _declination(l, b),
    distance: 6378.14 / math.sin(_rad * _moonParallax(t)),
  );
}

SkyPosition _position(
  _Equatorial coordinates,
  double d,
  double latitude,
  double longitude,
) {
  final double phi = _rad * latitude;
  final double h =
      _siderealAngle(d, _rad * -longitude) - coordinates.rightAscension;
  final double dec = coordinates.declination;
  return SkyPosition(
    azimuth: math.atan2(
      math.sin(h),
      math.cos(h) * math.sin(phi) - math.tan(dec) * math.cos(phi),
    ),
    altitude:
        math.asin(
          math.sin(phi) * math.sin(dec) +
              math.cos(phi) * math.cos(dec) * math.cos(h),
        ) /
        _rad,
  );
}

SkyPosition sunPosition(DateTime instant, double latitude, double longitude) {
  final double d = _daysSinceJ2000(instant);
  return _position(_sunCoordinates(d), d, latitude, longitude);
}

SkyPosition moonPosition(DateTime instant, double latitude, double longitude) {
  final double d = _daysSinceJ2000(instant);
  return _position(_moonCoordinates(d), d, latitude, longitude);
}

MoonIllumination moonIllumination(DateTime instant) {
  final double d = _daysSinceJ2000(instant);
  final _Equatorial s = _sunCoordinates(d);
  final _Equatorial m = _moonCoordinates(d);
  final double deltaRa = s.rightAscension - m.rightAscension;
  final double phi = math.acos(
    math.sin(s.declination) * math.sin(m.declination) +
        math.cos(s.declination) * math.cos(m.declination) * math.cos(deltaRa),
  );
  final double inc = math.atan2(
    _sunDistanceKm * math.sin(phi),
    m.distance - _sunDistanceKm * math.cos(phi),
  );
  final double angle = math.atan2(
    math.cos(s.declination) * math.sin(deltaRa),
    math.sin(s.declination) * math.cos(m.declination) -
        math.cos(s.declination) * math.sin(m.declination) * math.cos(deltaRa),
  );
  return MoonIllumination(
    fraction: (1 + math.cos(inc)) / 2,
    phase: 0.5 + 0.5 * inc * (angle < 0 ? -1 : 1) / math.pi,
  );
}

String moonPhaseName(double phase) {
  if (phase < 0.03 || phase > 0.97) {
    return 'new moon';
  }
  if (phase < 0.22) {
    return 'waxing crescent';
  }
  if (phase < 0.28) {
    return 'first quarter';
  }
  if (phase < 0.47) {
    return 'waxing gibbous';
  }
  if (phase < 0.53) {
    return 'full moon';
  }
  if (phase < 0.72) {
    return 'waning gibbous';
  }
  if (phase < 0.78) {
    return 'last quarter';
  }
  return 'waning crescent';
}

SkyPosition bodyPosition(
  SkyBody body,
  DateTime instant,
  double latitude,
  double longitude,
) => switch (body) {
  SkyBody.sun => sunPosition(instant, latitude, longitude),
  SkyBody.moon => moonPosition(instant, latitude, longitude),
};

bool _isUp(SkyBody body, DateTime instant, double latitude, double longitude) {
  final double altitude = bodyPosition(
    body,
    instant,
    latitude,
    longitude,
  ).altitude;
  return switch (body) {
    SkyBody.sun => altitude > _sunHorizonAltitude,
    SkyBody.moon =>
      altitude >
          0.7275 * _moonParallax(_daysSinceJ2000(instant) / 36525) - 0.5667,
  };
}

DateTime _minuteAt(int microseconds, bool isUtc) =>
    DateTime.fromMicrosecondsSinceEpoch(
      microseconds - microseconds % Duration.microsecondsPerMinute,
      isUtc: isUtc,
    );

DateTime _wholeMinute(DateTime instant) =>
    _minuteAt(instant.microsecondsSinceEpoch, instant.isUtc);

DateTime _nearestMinute(DateTime instant) => _minuteAt(
  instant.microsecondsSinceEpoch + Duration.microsecondsPerMinute ~/ 2,
  instant.isUtc,
);

DateTime _crossing(
  bool Function(DateTime instant) isUp,
  bool upBefore,
  DateTime before,
  DateTime after,
) {
  final Duration gap = after.difference(before);
  final DateTime middle = before.add(gap ~/ 2);
  if (gap <= _crossingPrecision) {
    return middle;
  }
  return isUp(middle) == upBefore
      ? _crossing(isUp, upBefore, middle, after)
      : _crossing(isUp, upBefore, before, middle);
}

SkyEvent? nextSkyEvent(
  SkyBody body,
  DateTime from,
  double latitude,
  double longitude,
) {
  final DateTime start = _wholeMinute(from);
  bool isUp(DateTime instant) => _isUp(body, instant, latitude, longitude);
  DateTime atMinute(int minutes) => start.add(Duration(minutes: minutes));
  bool up = isUp(start);
  for (int k = 1; k <= _coarseSteps; k++) {
    final int coarse = k * _coarseStepMinutes;
    if (isUp(atMinute(coarse)) == up) {
      continue;
    }
    final bool upBefore = up;
    final int flipped = Iterable<int>.generate(
      _coarseStepMinutes,
      (int step) => coarse - _coarseStepMinutes + 1 + step,
    ).firstWhere((int minute) => isUp(atMinute(minute)) != upBefore);
    final DateTime event = _nearestMinute(
      _crossing(isUp, upBefore, atMinute(flipped - 1), atMinute(flipped)),
    );
    if (event.isAfter(from)) {
      return SkyEvent(instant: event, isRise: !upBefore);
    }
    up = !upBefore;
  }
  return null;
}
