import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/domain/mood/mood.dart';
import 'package:field_notes/features/mood/mood_picker_grid.dart';
import 'package:field_notes/features/mood/mood_picker_sheet.dart';

import 'support/mood_harness.dart';

void main() {
  testWidgets('renders the title and the ten-mood grid',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      moodHarness(
        MoodPickerSheet(selected: null, onMoodSelected: (_) {}),
      ),
    );

    expect(find.text('How are you feeling?'), findsOneWidget);
    expect(find.byType(MoodPickerGrid), findsOneWidget);
    for (final Mood mood in moodOrder) {
      expect(find.text(mood.label), findsOneWidget);
    }
  });

  testWidgets('forwards the selected mood', (WidgetTester tester) async {
    Mood? picked;
    await tester.pumpWidget(
      moodHarness(
        MoodPickerSheet(
          selected: Mood.happy,
          onMoodSelected: (Mood mood) => picked = mood,
        ),
      ),
    );

    await tester.tap(find.text('Sad'));
    expect(picked, Mood.sad);
  });
}
