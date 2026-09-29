import 'package:field_notes/features/garden/sky/sky_astronomy.dart';
import 'package:flutter_test/flutter_test.dart';

class Place {
  const Place(this.name, this.latitude, this.longitude, this.utcOffsetHours);

  final String name;
  final double latitude;
  final double longitude;
  final int utcOffsetHours;
}

const Place edmonton = Place('Edmonton', 53.55, -113.4667, -6);
const Place london = Place('London', 51.5083, -0.1253, 1);
const Place sydney = Place('Sydney', -33.8667, 151.2167, 11);
const Place oslo = Place('Oslo', 59.9167, 10.75, 2);

class PositionFixture {
  const PositionFixture({
    required this.place,
    required this.instant,
    required this.sunAltitude,
    required this.sunAzimuth,
    required this.moonAltitude,
    required this.moonAzimuth,
    required this.fraction,
    required this.phase,
    required this.phaseName,
  });

  final Place place;
  final String instant;
  final double sunAltitude;
  final double sunAzimuth;
  final double moonAltitude;
  final double moonAzimuth;
  final double fraction;
  final double phase;
  final String phaseName;
}

const List<PositionFixture> positionFixtures = <PositionFixture>[
  PositionFixture(
    place: edmonton,
    instant: '2026-09-28T18:00:00Z',
    sunAltitude: 31.777,
    sunAzimuth: -0.4283,
    moonAltitude: -10.529,
    moonAzimuth: 2.3959,
    fraction: 0.9454,
    phase: 0.5751,
    phaseName: 'waning gibbous',
  ),
  PositionFixture(
    place: edmonton,
    instant: '2026-09-29T00:00:00Z',
    sunAltitude: 10.331,
    sunAzimuth: 1.2545,
    moonAltitude: -9.794,
    moonAzimuth: -2.4250,
    fraction: 0.9318,
    phase: 0.5841,
    phaseName: 'waning gibbous',
  ),
  PositionFixture(
    place: london,
    instant: '2026-06-21T12:00:00Z',
    sunAltitude: 61.931,
    sunAzimuth: -0.0031,
    moonAltitude: 2.895,
    moonAzimuth: -1.5086,
    fraction: 0.4637,
    phase: 0.2384,
    phaseName: 'first quarter',
  ),
  PositionFixture(
    place: sydney,
    instant: '2026-12-01T02:00:00Z',
    sunAltitude: 77.215,
    sunAzimuth: 2.8068,
    moonAltitude: -7.150,
    moonAzimuth: 1.6587,
    fraction: 0.5169,
    phase: 0.7446,
    phaseName: 'last quarter',
  ),
  PositionFixture(
    place: oslo,
    instant: '2026-06-21T22:00:00Z',
    sunAltitude: -5.164,
    sunAzimuth: 2.8332,
    moonAltitude: 7.146,
    moonAzimuth: 1.2624,
    fraction: 0.5069,
    phase: 0.2522,
    phaseName: 'first quarter',
  ),
];

class PublishedEvent {
  const PublishedEvent(this.place, this.body, this.isRise, this.localTime);

  final Place place;
  final SkyBody body;
  final bool isRise;
  final String localTime;

  DateTime get instant {
    final DateTime clock = DateTime.parse('${localTime}Z');
    return clock.subtract(Duration(hours: place.utcOffsetHours));
  }

  String get label =>
      '${place.name} ${body.name} ${isRise ? 'rise' : 'set'} $localTime';
}

const List<PublishedEvent> publishedEvents = <PublishedEvent>[
  PublishedEvent(edmonton, SkyBody.sun, true, '2026-09-28T07:31'),
  PublishedEvent(edmonton, SkyBody.sun, false, '2026-09-28T19:17'),
  PublishedEvent(edmonton, SkyBody.moon, true, '2026-09-28T19:28'),
  PublishedEvent(edmonton, SkyBody.moon, false, '2026-09-28T10:24'),
  PublishedEvent(edmonton, SkyBody.sun, true, '2026-09-29T07:32'),
  PublishedEvent(edmonton, SkyBody.sun, false, '2026-09-29T19:15'),
  PublishedEvent(edmonton, SkyBody.moon, true, '2026-09-29T19:48'),
  PublishedEvent(edmonton, SkyBody.moon, false, '2026-09-29T11:55'),
  PublishedEvent(london, SkyBody.sun, true, '2026-06-21T04:43'),
  PublishedEvent(london, SkyBody.sun, false, '2026-06-21T21:21'),
  PublishedEvent(london, SkyBody.moon, true, '2026-06-21T12:41'),
  PublishedEvent(london, SkyBody.moon, false, '2026-06-21T00:34'),
  PublishedEvent(sydney, SkyBody.sun, true, '2026-12-01T05:37'),
  PublishedEvent(sydney, SkyBody.sun, false, '2026-12-01T19:51'),
  PublishedEvent(sydney, SkyBody.moon, true, '2026-12-01T00:55'),
  PublishedEvent(sydney, SkyBody.moon, false, '2026-12-01T12:24'),
  PublishedEvent(oslo, SkyBody.sun, true, '2026-06-21T03:54'),
  PublishedEvent(oslo, SkyBody.sun, false, '2026-06-21T22:44'),
  PublishedEvent(oslo, SkyBody.moon, true, '2026-06-21T12:54'),
  PublishedEvent(oslo, SkyBody.moon, false, '2026-06-21T00:57'),
  PublishedEvent(oslo, SkyBody.sun, true, '2026-06-22T03:54'),
  PublishedEvent(oslo, SkyBody.sun, false, '2026-06-22T22:44'),
  PublishedEvent(oslo, SkyBody.moon, true, '2026-06-22T14:22'),
  PublishedEvent(oslo, SkyBody.moon, false, '2026-06-22T00:57'),
];

DateTime utc(String iso) => DateTime.parse(iso);

void main() {
  test('sun and moon positions match the reference fixtures', () {
    for (final PositionFixture f in positionFixtures) {
      final DateTime instant = utc(f.instant);
      final SkyPosition sun = sunPosition(
        instant,
        f.place.latitude,
        f.place.longitude,
      );
      final SkyPosition moon = moonPosition(
        instant,
        f.place.latitude,
        f.place.longitude,
      );
      final String at = '${f.place.name} ${f.instant}';
      expect(sun.altitude, closeTo(f.sunAltitude, 0.01), reason: '$at sun');
      expect(sun.azimuth, closeTo(f.sunAzimuth, 0.0005), reason: '$at sun');
      expect(moon.altitude, closeTo(f.moonAltitude, 0.01), reason: '$at moon');
      expect(moon.azimuth, closeTo(f.moonAzimuth, 0.0005), reason: '$at moon');
    }
  });

  test('illumination and phase names match the reference fixtures', () {
    for (final PositionFixture f in positionFixtures) {
      final MoonIllumination illumination = moonIllumination(utc(f.instant));
      final String at = '${f.place.name} ${f.instant}';
      expect(illumination.fraction, closeTo(f.fraction, 0.0005), reason: at);
      expect(illumination.phase, closeTo(f.phase, 0.0005), reason: at);
      expect(moonPhaseName(illumination.phase), f.phaseName, reason: at);
    }

    const List<(double, String)> boundaries = <(double, String)>[
      (0.0, 'new moon'),
      (0.0299, 'new moon'),
      (0.03, 'waxing crescent'),
      (0.2199, 'waxing crescent'),
      (0.22, 'first quarter'),
      (0.2799, 'first quarter'),
      (0.28, 'waxing gibbous'),
      (0.4699, 'waxing gibbous'),
      (0.47, 'full moon'),
      (0.5299, 'full moon'),
      (0.53, 'waning gibbous'),
      (0.7199, 'waning gibbous'),
      (0.72, 'last quarter'),
      (0.7799, 'last quarter'),
      (0.78, 'waning crescent'),
      (0.97, 'waning crescent'),
      (0.9701, 'new moon'),
      (1.0, 'new moon'),
    ];
    for (final (double phase, String name) in boundaries) {
      expect(moonPhaseName(phase), name, reason: 'phase $phase');
    }
  });

  test('next rise and set events match the reference fixtures', () {
    void expectEvent(
      Place place,
      SkyBody body,
      String from,
      String at,
      bool isRise,
    ) {
      final SkyEvent? event = nextSkyEvent(
        body,
        utc(from),
        place.latitude,
        place.longitude,
      );
      expect(
        event,
        SkyEvent(instant: utc(at), isRise: isRise),
        reason: '${place.name} ${body.name} from $from',
      );
    }

    expectEvent(
      edmonton,
      SkyBody.sun,
      '2026-09-28T18:00:00Z',
      '2026-09-29T01:17:00Z',
      false,
    );
    expectEvent(
      edmonton,
      SkyBody.moon,
      '2026-09-28T18:00:00Z',
      '2026-09-29T01:29:00Z',
      true,
    );
    expectEvent(
      london,
      SkyBody.sun,
      '2026-06-21T12:00:00Z',
      '2026-06-21T20:20:00Z',
      false,
    );
    expectEvent(
      london,
      SkyBody.moon,
      '2026-06-21T12:00:00Z',
      '2026-06-21T23:47:00Z',
      false,
    );
    expectEvent(
      sydney,
      SkyBody.sun,
      '2026-12-01T02:00:00Z',
      '2026-12-01T08:49:00Z',
      false,
    );
    expectEvent(
      sydney,
      SkyBody.moon,
      '2026-12-01T02:00:00Z',
      '2026-12-01T14:25:00Z',
      true,
    );
    expectEvent(
      oslo,
      SkyBody.sun,
      '2026-06-21T22:00:00Z',
      '2026-06-22T01:52:00Z',
      true,
    );
    expectEvent(
      oslo,
      SkyBody.moon,
      '2026-06-21T22:00:00Z',
      '2026-06-21T22:58:00Z',
      false,
    );
  });

  test('the polar summer sun has no event within 36 hours', () {
    expect(
      nextSkyEvent(SkyBody.sun, utc('2026-06-21T12:00:00Z'), 78.2, 15.6),
      isNull,
    );
  });

  test('rise and set times land within 3 minutes of the Naval Observatory', () {
    for (final PublishedEvent published in publishedEvents) {
      final DateTime start = published.instant.subtract(
        const Duration(hours: 6),
      );
      SkyEvent? event = nextSkyEvent(
        published.body,
        start,
        published.place.latitude,
        published.place.longitude,
      );
      while (event != null && event.isRise != published.isRise) {
        event = nextSkyEvent(
          published.body,
          event.instant,
          published.place.latitude,
          published.place.longitude,
        );
      }
      expect(event, isNotNull, reason: published.label);
      final int minutesOff = event!.instant
          .difference(published.instant)
          .inMinutes
          .abs();
      expect(minutesOff, lessThanOrEqualTo(3), reason: published.label);
    }
  });

  test('noon illumination is within 0.01 of the Naval Observatory', () {
    const Map<String, double> noonFractions = <String, double>{
      '2026-09-28T18:00:00Z': 0.95,
      '2026-09-29T18:00:00Z': 0.88,
      '2026-06-21T11:00:00Z': 0.45,
      '2026-12-01T01:00:00Z': 0.52,
      '2026-06-21T10:00:00Z': 0.45,
      '2026-06-22T10:00:00Z': 0.55,
    };
    noonFractions.forEach((String instant, double fraction) {
      expect(
        moonIllumination(utc(instant)).fraction,
        closeTo(fraction, 0.01),
        reason: instant,
      );
    });
  });
}
