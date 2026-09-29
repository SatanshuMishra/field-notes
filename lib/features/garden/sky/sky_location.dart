import 'package:field_notes/features/garden/sky/zone_coordinates.dart';

class SkyLocation {
  const SkyLocation({
    required this.latitude,
    required this.longitude,
    required this.placeName,
  });

  final double latitude;
  final double longitude;
  final String placeName;
}

SkyLocation resolveSkyLocation(String? zone, Duration utcOffset) {
  final String? resolved = zone == null
      ? null
      : legacyZoneAliases[zone] ?? zone;
  final (double, double)? coordinates = resolved == null
      ? null
      : zoneCoordinates[resolved];
  if (resolved == null || coordinates == null) {
    return SkyLocation(
      latitude: 40,
      longitude: utcOffset.inMinutes / 4,
      placeName: 'home',
    );
  }
  return SkyLocation(
    latitude: coordinates.$1,
    longitude: coordinates.$2,
    placeName: resolved.split('/').last.replaceAll('_', ' '),
  );
}
