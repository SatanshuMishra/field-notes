import 'dart:math' as math;

import 'package:field_notes/features/garden/sky/sky_astronomy.dart';
import 'package:flutter_test/flutter_test.dart';

const double _edmontonLat = 53.55;
const double _edmontonLon = -113.4667;

class _Observed {
  const _Observed(this.lat, this.lon, this.instant, this.isRise);

  final double lat;
  final double lon;
  final String instant;
  final bool isRise;
}

const List<_Observed> _sunEvents = <_Observed>[
  _Observed(_edmontonLat, _edmontonLon, '2026-03-20T01:46:00Z', false),
  _Observed(_edmontonLat, _edmontonLon, '2026-03-20T13:36:00Z', true),
  _Observed(_edmontonLat, _edmontonLon, '2026-06-21T04:07:00Z', false),
  _Observed(_edmontonLat, _edmontonLon, '2026-06-21T11:04:00Z', true),
  _Observed(_edmontonLat, _edmontonLon, '2026-09-28T13:31:00Z', true),
  _Observed(_edmontonLat, _edmontonLon, '2026-09-29T01:17:00Z', false),
  _Observed(_edmontonLat, _edmontonLon, '2026-09-29T13:32:00Z', true),
  _Observed(_edmontonLat, _edmontonLon, '2026-09-30T01:15:00Z', false),
  _Observed(_edmontonLat, _edmontonLon, '2026-12-21T15:48:00Z', true),
  _Observed(_edmontonLat, _edmontonLon, '2026-12-21T23:16:00Z', false),
  _Observed(51.5083, -0.1253, '2026-06-21T03:43:00Z', true),
  _Observed(51.5083, -0.1253, '2026-06-21T20:21:00Z', false),
  _Observed(-33.8667, 151.2167, '2026-11-30T18:37:00Z', true),
  _Observed(-33.8667, 151.2167, '2026-12-01T08:51:00Z', false),
];

class _Placed {
  const _Placed(this.lat, this.lon, this.instant, this.altitude, this.azimuth);

  final double lat;
  final double lon;
  final String instant;
  final double altitude;
  final double azimuth;
}

const List<_Placed> _sunPlaces = <_Placed>[
  _Placed(
    _edmontonLat,
    _edmontonLon,
    '2026-09-28T18:00:00Z',
    31.497048,
    155.037748,
  ),
  _Placed(
    _edmontonLat,
    _edmontonLon,
    '2026-09-29T00:00:00Z',
    10.417965,
    251.422077,
  ),
  _Placed(51.5083, -0.1253, '2026-06-21T12:00:00Z', 61.925991, 178.869703),
  _Placed(-33.8667, 151.2167, '2026-12-01T02:00:00Z', 77.407711, 342.699418),
  _Placed(59.9167, 10.75, '2026-06-21T22:00:00Z', -5.091796, 341.885255),
];

double _compassDegrees(double southAzimuthRadians) =>
    (southAzimuthRadians * 180 / math.pi + 180) % 360;

void main() {
  test('sun rise and set land within one minute of the Naval Observatory', () {
    for (final _Observed observed in _sunEvents) {
      final DateTime at = DateTime.parse(observed.instant);
      SkyEvent? event = nextSkyEvent(
        SkyBody.sun,
        at.subtract(const Duration(hours: 3)),
        observed.lat,
        observed.lon,
      );
      while (event != null && event.isRise != observed.isRise) {
        event = nextSkyEvent(
          SkyBody.sun,
          event.instant,
          observed.lat,
          observed.lon,
        );
      }
      expect(event, isNotNull, reason: observed.instant);
      final double minutesOff =
          event!.instant.difference(at).inSeconds.abs() / 60;
      expect(
        minutesOff,
        lessThanOrEqualTo(1),
        reason: '${observed.instant} got ${event.instant}',
      );
    }
  });

  test(
    'sun altitude and azimuth match the Naval Observatory within 0.05 degrees',
    () {
      for (final _Placed placed in _sunPlaces) {
        final SkyPosition sun = sunPosition(
          DateTime.parse(placed.instant),
          placed.lat,
          placed.lon,
        );
        expect(
          sun.altitude,
          closeTo(placed.altitude, 0.05),
          reason: placed.instant,
        );
        expect(
          _compassDegrees(sun.azimuth),
          closeTo(placed.azimuth, 0.05),
          reason: placed.instant,
        );
      }
    },
  );

  test(
    'the next event falls on a whole minute whatever the seconds of the start',
    () {
      final SkyEvent? early = nextSkyEvent(
        SkyBody.sun,
        DateTime.utc(2026, 9, 29, 17, 14, 5),
        _edmontonLat,
        _edmontonLon,
      );
      final SkyEvent? late = nextSkyEvent(
        SkyBody.sun,
        DateTime.utc(2026, 9, 29, 17, 14, 50),
        _edmontonLat,
        _edmontonLon,
      );
      expect(early, isNotNull);
      expect(early!.instant.second, 0);
      expect(early.instant.millisecond, 0);
      expect(late, early);
    },
  );
}
