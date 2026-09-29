import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/garden/model/garden_data.dart';
import 'package:field_notes/features/garden/widgets/mood_tally_chips.dart';

import '../../support/theme_harness.dart';

const Color _cardBright = Color(0xFF211B16);
const Color _line = Color(0xFF9D8870);
const Color _shadow = Color(0xFF070504);
const Color _ink = Color(0xFFEFE3CE);
const Color _muted = Color(0xFFA6917A);

Color? _textColour(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style?.color;

void main() {
  test('garden names no light-only colour', () {
    expect(lightOnlyTokenUses(<String>['lib/features/garden']), isEmpty);
  });

  testWidgets('mood tally chips draw their dark colours', (
    WidgetTester tester,
  ) async {
    await pumpThemed(
      tester,
      const Align(
        alignment: Alignment.topLeft,
        child: MoodTallyChips(
          entries: <MoodTallyEntry>[MoodTallyEntry(mood: Mood.happy, count: 4)],
        ),
      ),
      brightness: Brightness.dark,
    );

    final BoxDecoration chip = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(MoodTallyChips),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((DecoratedBox box) => box.decoration)
        .whereType<BoxDecoration>()
        .where((BoxDecoration decoration) => decoration.color != null)
        .single;
    expect(chip.color, _cardBright);
    expect((chip.border! as Border).top.color, _line);
    expect(chip.boxShadow, hasLength(1));
    expect(chip.boxShadow!.single.color, _shadow);
    expect(chip.boxShadow!.single.blurRadius, 0);
    expect(_textColour(tester, '4'), _ink);
    expect(_textColour(tester, 'Happy'), _muted);
  });
}
