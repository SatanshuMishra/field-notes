import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/domain/mood/mood.dart';
import 'package:field_notes/features/mood/mood_picker_grid.dart';

import 'support/mood_harness.dart';

void main() {
  testWidgets('renders all ten moods and reports the tapped mood',
      (WidgetTester tester) async {
    Mood? tapped;
    await tester.pumpWidget(
      moodHarness(
        MoodPickerGrid(
          selected: null,
          onMoodSelected: (Mood mood) => tapped = mood,
        ),
      ),
    );

    for (final Mood mood in moodOrder) {
      expect(find.text(mood.label), findsOneWidget);
    }

    await tester.tap(find.text('Anxious'));
    expect(tapped, Mood.anxious);
  });

  testWidgets('marks only the selected mood as selected',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      moodHarness(
        MoodPickerGrid(selected: Mood.love, onMoodSelected: (_) {}),
      ),
    );

    final Finder selectedTiles = find.byWidgetPredicate(
      (Widget widget) =>
          widget is Semantics && widget.properties.selected == true,
    );
    expect(selectedTiles, findsOneWidget);
  });
}
