import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/features/settings/widgets/settings_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpRail(WidgetTester tester) => tester.pumpWidget(
  MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: fieldNotesTheme(platform: TargetPlatform.macOS),
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SettingsTabRail(
          selected: SettingsTab.journal,
          onSelected: (_) {},
          marked: SettingsTab.values.toSet(),
        ),
      ),
    ),
  ),
);

List<String> _wordsSplitAcrossLines(Finder texts) {
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
  testWidgets('at twice the text size every tab label keeps its words whole', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pumpRail(tester);

    expect(
      _wordsSplitAcrossLines(
        find.descendant(
          of: find.byType(SettingsTabRail),
          matching: find.byType(RichText),
        ),
      ),
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('at the default text size the rail keeps its set width', (
    WidgetTester tester,
  ) async {
    await _pumpRail(tester);

    expect(
      tester.getSize(find.byType(SettingsTabRail)).width,
      settingsTabRailWidth,
    );
  });
}
