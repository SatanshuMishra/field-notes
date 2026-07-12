import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/tokens/tokens.dart';

void main() {
  group('typography to pubspec family consistency', () {
    late String pubspec;

    setUpAll(() {
      pubspec = File('pubspec.yaml').readAsStringSync();
    });

    test('every typography family is a registered pubspec family', () {
      for (final family in <String>[
        TypographyTokens.serif,
        TypographyTokens.sans,
        TypographyTokens.accent,
      ]) {
        expect(pubspec, contains('family: $family'),
            reason: '$family must be registered in the pubspec fonts block');
      }
    });

    test('scale styles reference the declared families', () {
      expect(TypographyTokens.bodySerif.fontFamily, TypographyTokens.serif);
      expect(TypographyTokens.labelSans.fontFamily, TypographyTokens.sans);
      expect(TypographyTokens.eyebrowAccent.fontFamily, TypographyTokens.accent);
    });
  });

  group('sticker-cutout surface tokens', () {
    test('card and button shadows are hard non-blurred offsets', () {
      for (final shadow in <BoxShadow>[...Shadows.card, ...Shadows.button]) {
        expect(shadow.blurRadius, 0,
            reason: 'the sticker cutout uses a hard, non-blurred offset shadow');
      }
    });

    test('shadow offsets match the spec (3px card, 1.5px button)', () {
      expect(Shadows.card.single.offset, const Offset(3, 3));
      expect(Shadows.button.single.offset, const Offset(1.5, 1.5));
    });

    test('outline is a 1.5px ink border', () {
      expect(Shapes.outlineWidth, 1.5);
      expect(Shapes.outline.top.color, Palette.ink);
    });
  });
}
