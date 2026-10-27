import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/domain/mood/mood.dart';
import 'package:field_notes/features/mood/mood_picker_grid.dart';

import 'support/mood_harness.dart';

const double _panelGridWidth = 376;
const Size _tallView = Size(800, 1400);

List<String> _wordsSplitAcrossLines(WidgetTester tester, Finder texts) {
  final List<String> split = <String>[];
  for (final Element element in texts.evaluate()) {
    final RenderParagraph paragraph = element.renderObject! as RenderParagraph;
    final String text = paragraph.text.toPlainText();
    for (final RegExpMatch word in RegExp(r'\S+').allMatches(text)) {
      final Set<double> lineTops = paragraph
          .getBoxesForSelection(
            TextSelection(baseOffset: word.start, extentOffset: word.end),
          )
          .map((TextBox box) => box.top)
          .toSet();
      if (lineTops.length > 1) {
        split.add(word[0]!);
      }
    }
  }
  return split;
}

void main() {
  testWidgets('renders all ten moods and reports the tapped mood', (
    WidgetTester tester,
  ) async {
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

  testWidgets('marks only the selected mood as selected', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      moodHarness(MoodPickerGrid(selected: Mood.love, onMoodSelected: (_) {})),
    );

    final Finder selectedTiles = find.byWidgetPredicate(
      (Widget widget) =>
          widget is Semantics && widget.properties.selected == true,
    );
    expect(selectedTiles, findsOneWidget);
  });

  testWidgets('at twice the text size the panel grid keeps every mood and '
      'flower name whole', (WidgetTester tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = _tallView;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      moodHarness(
        SizedBox(
          width: _panelGridWidth,
          child: MoodPickerGrid(selected: null, onMoodSelected: (_) {}),
        ),
      ),
    );

    expect(_wordsSplitAcrossLines(tester, find.byType(RichText)), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'at the default text size the panel grid keeps four moods a row',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        moodHarness(
          SizedBox(
            width: _panelGridWidth,
            child: MoodPickerGrid(selected: null, onMoodSelected: (_) {}),
          ),
        ),
      );

      expect(
        moodOrder
            .take(4)
            .map((Mood mood) => tester.getTopLeft(find.text(mood.label)).dy)
            .toSet(),
        hasLength(1),
      );
    },
  );
}
