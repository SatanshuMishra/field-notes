import 'package:field_notes/features/garden/sky/sky_location.dart';
import 'package:field_notes/features/garden/sky/sky_location_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void expectLocation(
  SkyLocation actual,
  double latitude,
  double longitude,
  String placeName,
) {
  expect(actual.latitude, closeTo(latitude, 0.0001));
  expect(actual.longitude, closeTo(longitude, 0.0001));
  expect(actual.placeName, placeName);
}

void main() {
  test('known zones resolve to their zone table coordinates and city', () {
    expectLocation(
      resolveSkyLocation('America/Edmonton', Duration.zero),
      53.55,
      -113.4667,
      'Edmonton',
    );
    expectLocation(
      resolveSkyLocation('America/Argentina/Buenos_Aires', Duration.zero),
      -34.6,
      -58.45,
      'Buenos Aires',
    );
    expectLocation(
      resolveSkyLocation('Europe/London', Duration.zero),
      51.5083,
      -0.1253,
      'London',
    );
  });

  test('legacy zone names resolve to their current zone', () {
    expectLocation(
      resolveSkyLocation('Asia/Calcutta', Duration.zero),
      22.5333,
      88.3667,
      'Kolkata',
    );
  });

  test('unknown zones fall back to the UTC offset and home', () {
    expectLocation(
      resolveSkyLocation('Etc/Unknown', const Duration(hours: -6)),
      40,
      -90,
      'home',
    );
  });

  test('a failing time-zone lookup falls back to the UTC offset', () async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        localTimezoneIdentifierProvider.overrideWith(
          (ref) => throw StateError('no zone'),
        ),
        localUtcOffsetProvider.overrideWithValue(const Duration(hours: 9)),
      ],
    );
    addTearDown(container.dispose);
    final SkyLocation location = await container.read(
      skyLocationProvider.future,
    );
    expectLocation(location, 40, 135, 'home');
  });
}
