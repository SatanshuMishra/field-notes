import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';

import 'widget_harness.dart';

BoxDecoration _buttonDecoration(WidgetTester tester) {
  final DecoratedBox box = tester.widget<DecoratedBox>(
    find.descendant(
      of: find.byType(StickerButton),
      matching: find.byType(DecoratedBox),
    ),
  );
  return box.decoration as BoxDecoration;
}

double _opacity(WidgetTester tester) {
  return tester
      .widget<Opacity>(
        find.descendant(
          of: find.byType(StickerButton),
          matching: find.byType(Opacity),
        ),
      )
      .opacity;
}

void main() {
  group('StickerButton', () {
    testWidgets('renders its label and invokes onPressed when tapped',
        (WidgetTester tester) async {
      int taps = 0;
      await tester.pumpWidget(
        stickerHarness(
          StickerButton(label: 'Save', onPressed: () => taps++),
        ),
      );

      expect(find.text('Save'), findsOneWidget);
      expect(_opacity(tester), 1.0);

      await tester.tap(find.byType(StickerButton));
      expect(taps, 1);
    });

    testWidgets('is inert and dimmed when disabled',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        stickerHarness(
          const StickerButton(label: 'Save', onPressed: null),
        ),
      );

      expect(_opacity(tester), 0.5);
      await tester.tap(find.byType(StickerButton), warnIfMissed: false);
    });

    testWidgets('carries the hard button shadow and outline',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        stickerHarness(
          StickerButton(label: 'Go', onPressed: () {}),
        ),
      );

      final BoxDecoration deco = _buttonDecoration(tester);
      expect(deco.boxShadow, Shadows.button);
      expect(deco.borderRadius, Shapes.buttonBorderRadius);
      expect((deco.border! as Border).top.color, Palette.ink);
    });

    testWidgets('fills with the coral primary colour by default',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        stickerHarness(StickerButton(label: 'Go', onPressed: () {})),
      );

      expect(_buttonDecoration(tester).color, Palette.coral);
    });

    testWidgets('fills with the danger surface for the danger variant',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        stickerHarness(
          StickerButton(
            label: 'Delete all',
            variant: StickerButtonVariant.danger,
            onPressed: () {},
          ),
        ),
      );

      expect(_buttonDecoration(tester).color, Palette.dangerSurface);
    });
  });
}
