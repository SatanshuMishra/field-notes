import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/entry_cards/cards/note_body.dart';

Widget noteBodyHarness(Widget child) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 360, child: child),
      ),
    ),
  );
}

void main() {
  group('NoteBody', () {
    testWidgets('renders the note text in the serif body style',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        noteBodyHarness(const NoteBody(text: 'a quiet morning')),
      );

      final Text text = tester.widget<Text>(find.text('a quiet morning'));
      expect(text.style!.fontFamily, TypographyTokens.serif);
    });

    testWidgets('shows an empty-note affordance for blank text',
        (WidgetTester tester) async {
      await tester.pumpWidget(noteBodyHarness(const NoteBody(text: '   ')));

      expect(find.text('Empty note'), findsOneWidget);
    });
  });
}
