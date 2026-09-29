import 'dart:ui';

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/garden/model/garden_data.dart';
import 'package:field_notes/features/garden/model/garden_motion.dart';
import 'package:field_notes/features/garden/sky/sky_scene.dart';
import 'package:field_notes/features/garden/widgets/meadow_scene.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/bench_recorder.dart';

const Size _desktopSurface = Size(1140, 766);
const Duration _animateFor = Duration(seconds: 10);
const int _bloomCount = 365;
const double _edmontonLatitude = 53.55;
const double _edmontonLongitude = -113.4667;
final DateTime _midnight = DateTime.utc(2026, 9, 29, 6);

final List<GardenBloomData> _yearOfBlooms = <GardenBloomData>[
  for (int day = 0; day < _bloomCount; day++)
    GardenBloomData(
      date: DateTime.utc(
        2026,
        1,
        1,
      ).add(Duration(days: day)).toIso8601String().substring(0, 10),
      mood: moodOrder[(day * 7 + day ~/ 5) % moodOrder.length],
    ),
];

void _adoptDesktopSurface(WidgetTester tester) {
  if (benchOnDevice) {
    return;
  }
  tester.view.physicalSize = _desktopSurface * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
}

Future<void> _recordFrames({
  required String id,
  required String what,
  required List<int> samplesUs,
  required Map<String, Object?> extra,
}) => BenchRecorder.instance.record(
  BenchMeasurement(
    id: id,
    what: what,
    samplesUs: List<int>.unmodifiable(samplesUs),
    extra: extra,
  ),
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('garden meadow frame build and raster over ten seconds', (
    WidgetTester tester,
  ) async {
    useLiveFrames(tester);
    _adoptDesktopSurface(tester);
    final double dpr = tester.view.devicePixelRatio;
    final Size logical = tester.view.physicalSize / dpr;
    BenchRecorder.instance.describeSurface(<String, Object?>{
      'logicalWidth': logical.width,
      'logicalHeight': logical.height,
      'devicePixelRatio': dpr,
    });

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MeadowScene(
          blooms: _yearOfBlooms,
          sky: skySceneAt(_midnight, _edmontonLatitude, _edmontonLongitude),
          seed: 2026,
          motion: GardenMotionProfile.full,
        ),
      ),
    );
    await tester.pump();

    final List<FrameTiming> timings = <FrameTiming>[];
    void collect(List<FrameTiming> batch) => timings.addAll(batch);
    SchedulerBinding.instance.addTimingsCallback(collect);
    await tester.binding.delayed(_animateFor);
    SchedulerBinding.instance.removeTimingsCallback(collect);

    final Map<String, Object?> extra = <String, Object?>{
      'blooms': _bloomCount,
      'seconds': _animateFor.inSeconds,
      'frames': timings.length,
      'sky': 'Edmonton ${_midnight.toIso8601String()}',
      'motion': 'forced full: sway, twinkle, fireflies',
      'budget': 'none; recorded for the live pass',
    };
    await _recordFrames(
      id: 'gardenFrameBuild',
      what:
          'UI thread build time of each engine frame while a '
          '$_bloomCount-bloom meadow animates for ${_animateFor.inSeconds} s',
      samplesUs: <int>[
        for (final FrameTiming timing in timings)
          timing.buildDuration.inMicroseconds,
      ],
      extra: extra,
    );
    await _recordFrames(
      id: 'gardenFrameRaster',
      what:
          'raster thread time of each engine frame while a '
          '$_bloomCount-bloom meadow animates for ${_animateFor.inSeconds} s',
      samplesUs: <int>[
        for (final FrameTiming timing in timings)
          timing.rasterDuration.inMicroseconds,
      ],
      extra: extra,
    );

    await tester.pumpWidget(const SizedBox());
  });
}
