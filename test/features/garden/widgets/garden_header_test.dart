import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/garden/garden.dart';
import 'package:field_notes/features/garden/model/garden_data.dart';
import 'package:field_notes/features/garden/sky/sky_location.dart';
import 'package:field_notes/features/garden/sky/sky_time.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final SkyMoment _moment = SkyMoment(instant: DateTime.utc(2026, 9, 28, 18));
final SkyLocation _edmonton = resolveSkyLocation(
  'America/Edmonton',
  const Duration(hours: -6),
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  TargetPlatform platform = TargetPlatform.macOS,
}) async {
  tester.view.physicalSize = const Size(1140, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: fieldNotesTheme(platform: platform),
      home: Scaffold(
        body: MediaQuery(
          data: const MediaQueryData(
            size: Size(1140, 900),
            disableAnimations: true,
          ),
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'the day count counts blooms and sprouts and says 1 day for one',
    (WidgetTester tester) async {
      await _pump(
        tester,
        GardenView(
          blooms: const <GardenBloomData>[
            GardenBloomData(date: '2026-03-01', mood: Mood.happy),
            GardenBloomData(date: '2026-03-02', mood: Mood.calm),
          ],
          tally: const <MoodTallyEntry>[
            MoodTallyEntry(mood: Mood.happy, count: 1),
            MoodTallyEntry(mood: Mood.calm, count: 1),
          ],
          sprouts: const <String>['2026-03-03'],
          year: 2026,
          moment: _moment,
          location: _edmonton,
        ),
      );
      expect(
        find.text(
          '3 days planted in 2026 · quietly filling in as the year goes',
        ),
        findsOneWidget,
      );

      await _pump(
        tester,
        GardenView(
          blooms: const <GardenBloomData>[],
          tally: const <MoodTallyEntry>[],
          sprouts: const <String>['2026-03-03'],
          year: 2026,
          moment: _moment,
          location: _edmonton,
        ),
      );
      expect(
        find.text(
          '1 day planted in 2026 · quietly filling in as the year goes',
        ),
        findsOneWidget,
      );

      await _pump(
        tester,
        const GardenHeader(compact: false, dayCount: 1, year: 2025),
      );
      expect(
        find.text(
          '1 day planted in 2025 · quietly filling in as the year goes',
        ),
        findsOneWidget,
      );

      await _pump(
        tester,
        const GardenHeader(compact: true, dayCount: 1, year: 2026),
        platform: TargetPlatform.android,
      );
      expect(find.text('1 day planted in 2026'), findsOneWidget);

      await _pump(
        tester,
        const GardenHeader(compact: true, dayCount: 12, year: 2026),
        platform: TargetPlatform.android,
      );
      expect(find.text('12 days planted in 2026'), findsOneWidget);

      await _pump(tester, const GardenHeader(compact: false));
      expect(find.text('your garden'), findsOneWidget);
      expect(find.textContaining('planted in'), findsNothing);
    },
  );
}
