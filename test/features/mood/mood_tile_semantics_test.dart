import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/domain/mood/mood.dart';
import 'package:field_notes/features/mood/mood_picker_grid.dart';

import 'support/mood_harness.dart';

void main() {
  testWidgets('a mood tile reads its mood once', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(
      moodHarness(
        MoodPickerGrid(selected: null, onMoodSelected: (Mood mood) {}),
      ),
    );

    final Finder happyTile = find
        .byWidgetPredicate(
          (Widget widget) =>
              widget is Semantics && widget.properties.button == true,
        )
        .first;

    expect(
      tester.getSemantics(happyTile),
      isSemantics(label: 'Happy'),
    );
    handle.dispose();
  });
}
