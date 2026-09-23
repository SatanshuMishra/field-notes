@Tags(<String>['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart';

import 'golden_harness.dart';

const double _pillGlyphSize = 14;
const double _pillButtonSize = 28;
const double _reviewGlyphSize = 96;

Future<void> _capture(WidgetTester tester, Widget subject, String name) async {
  pinGoldenSurface(tester);

  await tester.pumpWidget(goldenHarness(subject));

  await expectLater(
    find.byType(RepaintBoundary),
    matchesGoldenFile('images/$name.png'),
  );
}

void main() {
  testWidgets('the edit glyph matches its golden in the manage pill', (
    WidgetTester tester,
  ) async {
    await _capture(
      tester,
      const SizedBox.square(
        dimension: _pillButtonSize,
        child: ColoredBox(
          color: Palette.toolbarInk,
          child: Center(
            child: IconStickerGlyphIcon(
              glyph: IconStickerGlyph.edit,
              color: Palette.onAccent,
              size: _pillGlyphSize,
            ),
          ),
        ),
      ),
      'icon_sticker_edit_pill',
    );
  });

  testWidgets('the edit glyph matches its golden at review size', (
    WidgetTester tester,
  ) async {
    await _capture(
      tester,
      const ColoredBox(
        color: Palette.cardWarm,
        child: IconStickerGlyphIcon(
          glyph: IconStickerGlyph.edit,
          color: Palette.ink,
          size: _reviewGlyphSize,
        ),
      ),
      'icon_sticker_edit_review',
    );
  });
}
