import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/features/mood/mood_banner.dart';

int _count(String haystack, String needle) =>
    RegExp(RegExp.escape(needle)).allMatches(haystack).length;

void main() {
  testWidgets('the prompt names its question once and not the flower', (
    WidgetTester tester,
  ) async {
    const String question = 'How are you feeling today?';
    const String hint = "tap to plant today's bloom";
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Material(child: MoodBanner(mood: null, onChangeMood: () {})),
      ),
    );
    await tester.pump();

    final SemanticsNode node = tester.getSemantics(find.text(question));
    final String label = node.label;
    expect(_count(label, question), 1);
    expect(_count(label, hint), 1);
    expect(label.indexOf(hint), greaterThan(label.indexOf(question)));
    expect(label, isNot(contains('Peony')));
    expect(label, isNot(contains('choose')));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    handle.dispose();
  });
}
