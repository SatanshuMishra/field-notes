import 'package:flutter/services.dart';
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

    testWidgets('offers no retry control unless a callback is supplied',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        cardHarness(
          const CorruptMediaPlaceholder(
            label: "Can't play this video",
            height: 200,
          ),
        ),
      );

      expect(find.byKey(retryMediaKey), findsNothing);
      expect(find.text(retryMediaLabel), findsNothing);
    });

    testWidgets('renders a labelled retry control at the 48 pixel target floor',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        int retries = 0;
        await tester.pumpWidget(
          cardHarness(
            Shortcuts(
              shortcuts: WidgetsApp.defaultShortcuts,
              child: CorruptMediaPlaceholder(
                label: "Can't play this video",
                height: 200,
                onRetry: () => retries++,
              ),
            ),
          ),
        );

        expect(find.bySemanticsLabel(retryMediaLabel), findsOneWidget);
        final Size target = tester.getSize(find.byKey(retryMediaKey));
        expect(target.height, greaterThan(47.9));
        expect(target.width, greaterThan(47.9));

        Focus.of(tester.element(find.byKey(retryMediaKey))).requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();

        expect(retries, 1);

        await tester.tap(find.byKey(retryMediaKey));
        await tester.pump();

        expect(retries, 2);
      } finally {
        handle.dispose();
      }
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
