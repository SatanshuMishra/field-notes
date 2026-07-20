import 'package:field_notes/design/flowers/flowers.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/garden/model/garden_data.dart';
import 'package:field_notes/features/garden/widgets/mood_tally_chips.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: Align(alignment: Alignment.topLeft, child: child),
    );

void main() {
  testWidgets('renders one chip per entry with counts and labels',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _host(
        const MoodTallyChips(
          entries: <MoodTallyEntry>[
            MoodTallyEntry(mood: Mood.happy, count: 4),
            MoodTallyEntry(mood: Mood.calm, count: 2),
          ],
        ),
      ),
    );

    expect(find.byType(FlowerBloom), findsNWidgets(2));
    expect(find.text('4'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Happy'), findsOneWidget);
    expect(find.text('Calm'), findsOneWidget);
  });

  testWidgets('renders nothing for an empty tally',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _host(const MoodTallyChips(entries: <MoodTallyEntry>[])),
    );

    expect(find.byType(FlowerBloom), findsNothing);
    expect(find.byType(Wrap), findsNothing);
  });
}
