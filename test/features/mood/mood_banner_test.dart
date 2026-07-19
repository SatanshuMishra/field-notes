import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/domain/mood/mood.dart';
import 'package:field_notes/features/mood/mood_banner.dart';

import 'support/mood_harness.dart';

void main() {
  testWidgets('shows the prompt when no mood is set and reports change taps',
      (WidgetTester tester) async {
    int taps = 0;
    await tester.pumpWidget(
      moodHarness(
        MoodBanner(mood: null, onChangeMood: () => taps++),
      ),
    );

    expect(find.text('How are you feeling today?'), findsOneWidget);
    expect(find.text('Change mood'), findsNothing);

    await tester.tap(find.text('How are you feeling today?'));
    expect(taps, 1);
  });

  testWidgets('shows the flower, label and change button when a mood is set',
      (WidgetTester tester) async {
    int taps = 0;
    await tester.pumpWidget(
      moodHarness(
        MoodBanner(mood: Mood.calm, onChangeMood: () => taps++),
      ),
    );

    expect(find.text('Calm'), findsOneWidget);
    expect(find.text('Change mood'), findsOneWidget);
    expect(find.text('How are you feeling today?'), findsNothing);

    await tester.tap(find.text('Change mood'));
    expect(taps, 1);
  });

  testWidgets('is a non-button when onChangeMood is null',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      moodHarness(
        const MoodBanner(mood: null, onChangeMood: null),
      ),
    );

    expect(find.text('How are you feeling today?'), findsOneWidget);
    final Finder buttons = find.byWidgetPredicate(
      (Widget widget) =>
          widget is Semantics && widget.properties.button == true,
    );
    expect(buttons, findsNothing);
  });
}
