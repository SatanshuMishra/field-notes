import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/domain/mood/mood.dart';
import 'package:field_notes/features/mood/mood_picker.dart';

import 'support/mood_harness.dart';

void main() {
  testWidgets('opens the sheet and returns the picked mood',
      (WidgetTester tester) async {
    Mood? result;
    await tester.pumpWidget(
      moodHarness(
        Builder(
          builder: (BuildContext context) {
            return GestureDetector(
              onTap: () async {
                result = await showMoodPicker(context, selected: Mood.happy);
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('How are you feeling?'), findsOneWidget);

    await tester.tap(find.text('Calm'));
    await tester.pumpAndSettle();
    expect(result, Mood.calm);
    expect(find.text('How are you feeling?'), findsNothing);
  });

  testWidgets('returns null when dismissed by the barrier',
      (WidgetTester tester) async {
    Mood? result;
    bool completed = false;
    await tester.pumpWidget(
      moodHarness(
        Builder(
          builder: (BuildContext context) {
            return GestureDetector(
              onTap: () async {
                result = await showMoodPicker(context, selected: null);
                completed = true;
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('How are you feeling?'), findsOneWidget);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(completed, isTrue);
    expect(result, isNull);
  });
}
