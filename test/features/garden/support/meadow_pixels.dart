import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/core/capture_date.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/scene/meadow_palette.dart';
import 'package:field_notes/features/garden/sky/sky_scene.dart';

import 'garden_harness.dart';

const int meadowPixelsYear = 2028;
const double _latitude = 53.55;
const double _longitude = -113.4667;

MeadowYear meadowPixelsLeapYear() => MeadowYear.build(
  days: <Day>[
    for (int i = 0; i < 366; i++)
      dayOf(
        captureDateKey(DateTime(meadowPixelsYear, 1, 1 + i)),
        mood: moodOrder[(i ~/ 5) % moodOrder.length],
      ),
  ],
  entryCounts: const <String, int>{},
  year: meadowPixelsYear,
  today: DateTime(meadowPixelsYear + 1, 3, 1),
);

Map<String, MeadowPalette> meadowPixelsPalettes(MeadowYear year) =>
    <String, MeadowPalette>{
      for (final MapEntry<String, DateTime> entry in <String, DateTime>{
        'noon': DateTime.utc(meadowPixelsYear, 6, 21, 19, 30),
        'dusk': DateTime.utc(meadowPixelsYear, 6, 22, 4, 10),
        'midnight': DateTime.utc(meadowPixelsYear, 1, 15, 7),
      }.entries)
        entry.key: MeadowPalette.from(
          sky: skySceneAt(entry.value, _latitude, _longitude),
          morning: false,
          heavyShare: year.heavyShare,
        ),
    };

Future<Uint8List> rgbaOf(Image image) async {
  final ByteData data = (await image.toByteData(
    format: ImageByteFormat.rawRgba,
  ))!;
  return data.buffer.asUint8List();
}

List<int> sortedPixelDifferences(Uint8List a, Uint8List b) {
  final List<int> worst = <int>[];
  for (int i = 0; i < a.length; i += 4) {
    int difference = 0;
    for (int channel = 0; channel < 4; channel++) {
      final int d = (a[i + channel] - b[i + channel]).abs();
      if (d > difference) {
        difference = d;
      }
    }
    worst.add(difference);
  }
  return worst..sort();
}

int percentileOf(List<int> sorted, double share) =>
    sorted[math.min(sorted.length - 1, (sorted.length * share).floor())];
