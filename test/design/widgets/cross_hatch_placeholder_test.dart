import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';

import 'widget_harness.dart';

void main() {
  group('CrossHatchPlaceholder', () {
    testWidgets('honours the bounded size it is given',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        stickerHarness(
          const SizedBox(
            width: 120,
            height: 90,
            child: CrossHatchPlaceholder(),
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(CrossHatchPlaceholder)),
        const Size(120, 90),
      );
    });

    testWidgets('renders a centered child such as an error label',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        stickerHarness(
          const SizedBox(
            width: 120,
            height: 90,
            child: CrossHatchPlaceholder(child: Text('unreadable')),
          ),
        ),
      );

      expect(find.text('unreadable'), findsOneWidget);
    });

    testWidgets('paints the cross-hatch in the placeholder colour',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        stickerHarness(
          const SizedBox(
            width: 120,
            height: 90,
            child: CrossHatchPlaceholder(),
          ),
        ),
      );

      final CustomPaint paint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(CrossHatchPlaceholder),
          matching: find.byType(CustomPaint),
        ),
      );
      expect((paint.painter! as CrossHatchPainter).color, Palette.placeholder);
    });

    test('CrossHatchPainter repaints only when a paint input changes', () {
      const CrossHatchPainter base = CrossHatchPainter(color: Palette.placeholder);
      const CrossHatchPainter recoloured = CrossHatchPainter(color: Palette.ink);
      const CrossHatchPainter identical =
          CrossHatchPainter(color: Palette.placeholder);

      expect(base.shouldRepaint(recoloured), isTrue);
      expect(base.shouldRepaint(identical), isFalse);
    });
  });
}
