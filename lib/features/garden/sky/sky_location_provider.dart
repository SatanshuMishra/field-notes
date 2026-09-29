import 'package:field_notes/features/garden/sky/sky_location.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sky_location_provider.g.dart';

@riverpod
Future<String> localTimezoneIdentifier(Ref ref) async {
  final TimezoneInfo info = await FlutterTimezone.getLocalTimezone();
  return info.identifier;
}

@riverpod
Duration localUtcOffset(Ref ref) => DateTime.now().timeZoneOffset;

@riverpod
Future<SkyLocation> skyLocation(Ref ref) async {
  final Duration offset = ref.watch(localUtcOffsetProvider);
  String? zone;
  try {
    zone = await ref.watch(localTimezoneIdentifierProvider.future);
  } catch (_) {
    zone = null;
  }
  return resolveSkyLocation(zone, offset);
}
