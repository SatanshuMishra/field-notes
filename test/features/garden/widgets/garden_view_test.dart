import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/garden/model/garden_data.dart';
import 'package:field_notes/features/garden/model/garden_motion.dart';
import 'package:field_notes/features/garden/paint/meadow_painter.dart';
import 'package:field_notes/features/garden/widgets/garden_view.dart';
import 'package:field_notes/features/garden/widgets/meadow_scene.dart';
import 'package:field_notes/features/garden/widgets/mood_tally_chips.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const List<GardenBloomData> _twoBlooms = <GardenBloomData>[
  GardenBloomData(date: '2026-03-01', mood: Mood.happy),
  GardenBloomData(date: '2026-03-02', mood: Mood.calm),
];

const List<MoodTallyEntry> _twoTally = <MoodTallyEntry>[
  MoodTallyEntry(mood: Mood.happy, count: 1),
  MoodTallyEntry(mood: Mood.calm, count: 1),
];

Widget _host(Widget child, {bool disableAnimations = false}) => Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: MediaQueryData(
          size: const Size(400, 600),
          disableAnimations: disableAnimations,
        ),
        child: child,
      ),
    );

MeadowPainter _painter(WidgetTester tester) => tester
    .widget<CustomPaint>(
      find
          .descendant(
            of: find.byType(MeadowScene),
            matching: find.byType(CustomPaint),
          )
          .first,
    )
    .painter! as MeadowPainter;

void main() {
  testWidgets('shows the empty state when there are no blooms',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _host(
        const GardenView(
          blooms: <GardenBloomData>[],
          tally: <MoodTallyEntry>[],
          year: 2026,
        ),
      ),
    );

    expect(find.byType(EmptyStatePlaceholder), findsOneWidget);
    expect(find.byType(MeadowScene), findsNothing);
  });

  testWidgets('composes the meadow and the tally when blooms exist',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _host(
        const GardenView(
          blooms: _twoBlooms,
          tally: _twoTally,
          year: 2026,
          motionOverride: GardenMotionProfile.reduced,
        ),
      ),
    );

    expect(find.byType(MeadowScene), findsOneWidget);
    expect(find.byType(MoodTallyChips), findsOneWidget);
    expect(find.byType(EmptyStatePlaceholder), findsNothing);
    expect(find.text('Happy'), findsOneWidget);
  });

  testWidgets('degrades the scene when the platform disables animations',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _host(
        const GardenView(blooms: _twoBlooms, tally: _twoTally, year: 2026),
        disableAnimations: true,
      ),
    );

    expect(_painter(tester).showInsects, isFalse);
  });
}
