import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/tokens/tokens.dart';

import 'harness.dart';

DashedBorderPainter _painter(WidgetTester tester) {
  final CustomPaint paint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byType(EmptyStatePlaceholder),
      matching: find.byType(CustomPaint),
    ),
  );
  return paint.painter! as DashedBorderPainter;
}

void main() {
  group('EmptyStatePlaceholder', () {
    testWidgets('renders the message, icon, and action',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        feedbackHarness(
          const EmptyStatePlaceholder(
            message: 'No entries yet',
            icon: SizedBox(width: 24, height: 24),
            action: Text('Add a note'),
          ),
        ),
      );

      expect(find.text('No entries yet'), findsOneWidget);
      expect(find.text('Add a note'), findsOneWidget);
    });

    testWidgets('paints a dashed ink border by default',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        feedbackHarness(
          const EmptyStatePlaceholder(message: 'Empty'),
        ),
      );

      final DashedBorderPainter painter = _painter(tester);
      expect(painter.color, Palette.ink);
      expect(painter.dashLength, Shapes.dashLength);
      expect(painter.dashGap, Shapes.dashGap);
    });

    testWidgets('honours a custom border colour',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        feedbackHarness(
          const EmptyStatePlaceholder(
            message: 'Empty',
            borderColor: Palette.coral,
          ),
        ),
      );

      expect(_painter(tester).color, Palette.coral);
    });

    test('DashedBorderPainter repaints only when a paint input changes', () {
      const DashedBorderPainter base = DashedBorderPainter(color: Palette.ink);
      const DashedBorderPainter recoloured =
          DashedBorderPainter(color: Palette.coral);
      const DashedBorderPainter identical =
          DashedBorderPainter(color: Palette.ink);

      expect(base.shouldRepaint(recoloured), isTrue);
      expect(base.shouldRepaint(identical), isFalse);
    });
  });
}
