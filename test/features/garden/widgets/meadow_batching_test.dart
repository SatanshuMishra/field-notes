import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/garden/model/garden_data.dart';
import 'package:field_notes/features/garden/model/garden_motion.dart';
import 'package:field_notes/features/garden/paint/meadow_painter.dart';
import 'package:field_notes/features/garden/sky/sky_scene.dart';
import 'package:field_notes/features/garden/widgets/meadow_scene.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

final SkyScene _noon = skySceneAt(
  DateTime.utc(2026, 9, 28, 18),
  53.55,
  -113.4667,
);

List<GardenBloomData> _yearOf(int n) => List<GardenBloomData>.generate(
  n,
  (int i) => GardenBloomData(
    date: DateTime.utc(
      2024,
      1,
      1,
    ).add(Duration(days: i)).toIso8601String().substring(0, 10),
    mood: moodOrder[i % moodOrder.length],
  ),
);

void main() {
  testWidgets(
    'a 366-plant meadow draws its plants and grass in one batch per depth band',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(),
            child: Center(
              child: SizedBox(
                width: 1000,
                height: 452,
                child: MeadowScene(
                  blooms: _yearOf(366),
                  sky: _noon,
                  seed: 2024,
                  motion: GardenMotionProfile.full,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      final MeadowPainter painter =
          tester
                  .widget<CustomPaint>(
                    find.descendant(
                      of: find.byType(MeadowScene),
                      matching: find.byType(CustomPaint),
                    ),
                  )
                  .painter!
              as MeadowPainter;
      final TestRecordingCanvas canvas = TestRecordingCanvas();
      painter.paint(canvas, const Size(1000, 452));
      final List<Symbol> calls = <Symbol>[
        for (final RecordedInvocation call in canvas.invocations)
          call.invocation.memberName,
      ];
      expect(calls.where((Symbol name) => name == #drawPicture), isEmpty);
      final int batches = calls
          .where((Symbol name) => name == #drawAtlas)
          .length;
      expect(batches, greaterThan(0));
      expect(batches, lessThanOrEqualTo(painter.layout.bands.length));
    },
  );
}
