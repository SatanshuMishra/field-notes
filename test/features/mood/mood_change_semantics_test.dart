import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/domain/mood/mood.dart';
import 'package:field_notes/features/mood/mood_banner.dart';

import 'support/mood_harness.dart';

void main() {
  testWidgets('the change mood control reads its label once',
      (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(
      moodHarness(
        MoodBanner(mood: Mood.calm, onChangeMood: () {}),
      ),
    );

    final Finder target = find.ancestor(
      of: find.text('change'),
      matching: find.byType(GestureDetector),
    );
    expect(
      tester.getSemantics(target),
      isSemantics(label: 'change', isButton: true),
    );
    handle.dispose();
  });
}
