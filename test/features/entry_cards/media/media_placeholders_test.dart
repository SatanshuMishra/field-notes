import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/features/entry_cards/media/media_placeholders.dart';

import '../support/entry_cards_harness.dart';

void main() {
  group('CorruptMediaPlaceholder', () {
    testWidgets('renders its label on a danger cross-hatch surface',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        cardHarness(
          const CorruptMediaPlaceholder(
            label: "Can't open this photo",
            width: 80,
            height: 80,
          ),
        ),
      );

      expect(find.text("Can't open this photo"), findsOneWidget);
      final CrossHatchPlaceholder hatch = tester.widget<CrossHatchPlaceholder>(
        find.byType(CrossHatchPlaceholder),
      );
      expect(hatch.background, Palette.dangerSurface);
      expect(hatch.hatchColor, Palette.danger);
    });
  });

  group('NeutralMediaPlaceholder', () {
    testWidgets('renders a neutral cross-hatch with no label',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        cardHarness(const NeutralMediaPlaceholder(width: 80, height: 80)),
      );

      expect(find.byType(CrossHatchPlaceholder), findsOneWidget);
      expect(find.byType(Text), findsNothing);
    });
  });
}
