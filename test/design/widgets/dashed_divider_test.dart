import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';

import 'widget_harness.dart';

void main() {
  group('DashedDivider', () {
    testWidgets('lays out at the given thickness and fills the width',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        stickerHarness(
          const SizedBox(width: 200, child: DashedDivider()),
        ),
      );

      expect(tester.getSize(find.byType(DashedDivider)), const Size(200, 1.5));
    });

    testWidgets('paints an ink dashed line along the horizontal axis',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        stickerHarness(
          const SizedBox(width: 200, child: DashedDivider()),
        ),
      );

      final CustomPaint paint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(DashedDivider),
          matching: find.byType(CustomPaint),
        ),
      );
      final DashedLinePainter painter = paint.painter! as DashedLinePainter;
      expect(painter.color, Palette.ink);
      expect(painter.axis, Axis.horizontal);
      expect(painter.dashLength, Shapes.dashLength);
      expect(painter.dashGap, Shapes.dashGap);
    });

    test('DashedLinePainter repaints only when a paint input changes', () {
      const DashedLinePainter base = DashedLinePainter(
        axis: Axis.horizontal,
        thickness: 1.5,
        color: Palette.ink,
        dashLength: 6,
        dashGap: 4,
      );
      const DashedLinePainter recoloured = DashedLinePainter(
        axis: Axis.horizontal,
        thickness: 1.5,
        color: Palette.coral,
        dashLength: 6,
        dashGap: 4,
      );
      const DashedLinePainter identical = DashedLinePainter(
        axis: Axis.horizontal,
        thickness: 1.5,
        color: Palette.ink,
        dashLength: 6,
        dashGap: 4,
      );

      expect(base.shouldRepaint(recoloured), isTrue);
      expect(base.shouldRepaint(identical), isFalse);
    });
  });
}
