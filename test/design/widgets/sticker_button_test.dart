import 'package:flutter/services.dart';
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

EdgeInsetsGeometry _buttonPadding(WidgetTester tester) {
  return tester
      .widget<Padding>(
        find.descendant(
          of: find.byType(StickerButton),
          matching: find.byType(Padding),
        ),
      )
      .padding;
}

Color? _labelColour(WidgetTester tester, String label) {
  return tester.widget<Text>(find.text(label)).style?.color;
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

Widget _button(StickerButtonVariant variant) {
  return StickerButton(
    label: 'Go',
    variant: variant,
    onPressed: () {},
  );
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

    testWidgets('Enter and Space press a focused sticker button',
        (WidgetTester tester) async {
      int presses = 0;
      await tester.pumpWidget(
        stickerHarness(
          StickerButton(label: 'Save', onPressed: () => presses++),
        ),
      );

      final FocusNode? focus = Focus.maybeOf(tester.element(find.text('Save')));
      expect(focus, isNotNull);
      focus!.requestFocus();
      await tester.pump();
      expect(focus.hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(presses, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(presses, 2);
    });

    testWidgets('outlines every variant in 1.5px ink',
        (WidgetTester tester) async {
      for (final StickerButtonVariant variant in StickerButtonVariant.values) {
        await tester.pumpWidget(stickerHarness(_button(variant)));

        final Border border = _buttonDecoration(tester).border! as Border;
        expect(
          border.top.color,
          FieldNotesColors.light.line,
          reason: '$variant border colour',
        );
        expect(
          border.top.width,
          Shapes.outlineWidth,
          reason: '$variant border width',
        );
      }
    });

    testWidgets('lifts the default primary variant on the emphasis shadow',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        stickerHarness(StickerButton(label: 'Go', onPressed: () {})),
      );

      final BoxDecoration deco = _buttonDecoration(tester);
      expect(
        deco.boxShadow,
        FieldNotesShadows(FieldNotesColors.light).emphasis,
      );
      expect(deco.color, Palette.coral);
      expect(deco.borderRadius, BorderRadius.circular(Shapes.radiusControl));
      expect(_labelColour(tester, 'Go'), Palette.onAccent);
      expect(
        _buttonPadding(tester),
        const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      );
    });

    testWidgets('drops the shadow entirely for the secondary variant',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        stickerHarness(_button(StickerButtonVariant.secondary)),
      );

      final BoxDecoration deco = _buttonDecoration(tester);
      expect(deco.boxShadow, isNull);
      expect(deco.color, FieldNotesColors.light.cardWarm);
      expect(deco.borderRadius, BorderRadius.circular(Shapes.radiusControl));
      expect(_labelColour(tester, 'Go'), FieldNotesColors.light.ink);
      expect(
        _buttonPadding(tester),
        const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      );
    });

    testWidgets('fills the danger variant red on the control shadow',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        stickerHarness(_button(StickerButtonVariant.danger)),
      );

      final BoxDecoration deco = _buttonDecoration(tester);
      expect(deco.boxShadow, FieldNotesShadows(FieldNotesColors.light).control);
      expect(deco.color, Palette.danger);
      expect(deco.borderRadius, Shapes.buttonBorderRadius);
      expect(_labelColour(tester, 'Go'), Palette.onAccent);
      expect(
        _buttonPadding(tester),
        const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      );
    });
  });
}
