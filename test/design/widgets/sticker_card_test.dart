import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';

import 'widget_harness.dart';

BoxDecoration _cardDecoration(WidgetTester tester) {
  final DecoratedBox box = tester.widget<DecoratedBox>(
    find.descendant(
      of: find.byType(StickerCard),
      matching: find.byType(DecoratedBox),
    ),
  );
  return box.decoration as BoxDecoration;
}

void main() {
  group('StickerCard', () {
    testWidgets('renders its child', (WidgetTester tester) async {
      await tester.pumpWidget(
        stickerHarness(const StickerCard(child: Text('hello'))),
      );

      expect(find.text('hello'), findsOneWidget);
    });

    testWidgets('applies the sticker-cutout treatment from tokens',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        stickerHarness(const StickerCard(child: Text('hello'))),
      );

      final BoxDecoration deco = _cardDecoration(tester);
      expect(deco.color, Palette.cardWarm);
      expect(deco.borderRadius, Shapes.cardBorderRadius);
      expect(deco.boxShadow, Shadows.card);

      final Border border = deco.border! as Border;
      expect(border.top.color, Palette.ink);
      expect(border.top.width, Shapes.outlineWidth);
    });

    testWidgets('honours a custom surface colour',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        stickerHarness(
          const StickerCard(surface: Palette.cardBright, child: Text('x')),
        ),
      );

      expect(_cardDecoration(tester).color, Palette.cardBright);
    });

    testWidgets('inserts no transform at the default rotation',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        stickerHarness(const StickerCard(child: Text('hello'))),
      );

      expect(
        find.descendant(
          of: find.byType(StickerCard),
          matching: find.byType(Transform),
        ),
        findsNothing,
      );
    });

    testWidgets('tilts about its centre when given a rotation',
        (WidgetTester tester) async {
      const double tiltDegrees = -0.5;

      await tester.pumpWidget(
        stickerHarness(
          const StickerCard(
            rotationDegrees: tiltDegrees,
            child: Text('hello'),
          ),
        ),
      );

      final Transform transform = tester.widget<Transform>(
        find.descendant(
          of: find.byType(StickerCard),
          matching: find.byType(Transform),
        ),
      );

      expect(
          transform.transform, Matrix4.rotationZ(tiltDegrees * math.pi / 180));
      expect(transform.alignment, Alignment.center);
      expect(find.text('hello'), findsOneWidget);
    });
  });
}
