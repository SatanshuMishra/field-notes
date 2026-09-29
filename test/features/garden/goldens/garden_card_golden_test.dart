@Tags(<String>['golden'])
library;

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/garden/model/garden_data.dart';
import 'package:field_notes/features/garden/sky/sky_scene.dart';
import 'package:field_notes/features/garden/widgets/meadow_scene.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const double _edmontonLatitude = 53.55;
const double _edmontonLongitude = -113.4667;

final List<GardenBloomData> _sample = <GardenBloomData>[
  for (int i = 0; i < 40; i++)
    GardenBloomData(
      date: DateTime.utc(
        2026,
        1,
        1,
      ).add(Duration(days: i * 6)).toIso8601String().substring(0, 10),
      mood: moodOrder[(i * 7 + i ~/ 3) % moodOrder.length],
    ),
];

const List<(String, Size, bool)> _cards = <(String, Size, bool)>[
  ('desktop', Size(1000, 452), false),
  ('phone', Size(380, 320), true),
];

final List<(String, DateTime)> _instants = <(String, DateTime)>[
  ('noon', DateTime.utc(2026, 9, 28, 18)),
  ('dusk', DateTime.utc(2026, 9, 29, 1)),
  ('midnight', DateTime.utc(2026, 9, 29, 6)),
];

void main() {
  testWidgets(
    'desktop and phone garden cards at Edmonton noon, dusk and midnight',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      for (final (String layout, Size size, bool compact) in _cards) {
        tester.view.physicalSize = size;
        for (final (String time, DateTime instant) in _instants) {
          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: MediaQuery(
                data: MediaQueryData(size: size, disableAnimations: true),
                child: MeadowScene(
                  blooms: _sample,
                  sky: skySceneAt(
                    instant,
                    _edmontonLatitude,
                    _edmontonLongitude,
                  ),
                  seed: 2026,
                  compact: compact,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          await expectLater(
            find.descendant(
              of: find.byType(MeadowScene),
              matching: find.byType(RepaintBoundary),
            ),
            matchesGoldenFile('garden_card_${layout}_$time.png'),
          );
        }
      }
    },
  );
}
