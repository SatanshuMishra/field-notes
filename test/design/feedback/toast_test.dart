import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';

import 'harness.dart';

Color _surface(WidgetTester tester) {
  return tester.widget<StickerCard>(find.byType(StickerCard)).surface;
}

void main() {
  group('Toast', () {
    testWidgets('renders its message on a sticker surface',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        feedbackHarness(const Toast(message: 'Recording paused')),
      );

      expect(find.text('Recording paused'), findsOneWidget);
      expect(find.byType(StickerCard), findsOneWidget);
      expect(_surface(tester), Palette.cardBright);
    });

    testWidgets('honours a custom surface colour',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        feedbackHarness(
          const Toast(message: 'Saved', surface: Palette.cardWarm),
        ),
      );

      expect(_surface(tester), Palette.cardWarm);
    });
  });
}
