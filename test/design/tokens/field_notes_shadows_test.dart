import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/tokens/tokens.dart';

List<BoxShadow> _hard(Color color, double offset) => <BoxShadow>[
  BoxShadow(
    color: color,
    offset: Offset(offset, offset),
    blurRadius: 0,
    spreadRadius: 0,
  ),
];

void main() {
  group('FieldNotesShadows', () {
    test('light shadows and outline equal the live shadows and outline', () {
      const FieldNotesShadows shadows = FieldNotesShadows(
        FieldNotesColors.light,
      );

      expect(shadows.chip, _hard(const Color(0x294A3B2E), 1.5));
      expect(shadows.cellFilled, _hard(const Color(0x2E4A3B2E), 1.5));
      expect(shadows.control, _hard(const Color(0xFF4A3B2E), 1.5));
      expect(shadows.cardDefault, _hard(const Color(0x294A3B2E), 2));
      expect(shadows.emphasis, _hard(const Color(0xFF4A3B2E), 2));
      expect(shadows.phoneAction, _hard(const Color(0xFF4A3B2E), 2.5));
      expect(shadows.hero, _hard(const Color(0x334A3B2E), 3));
      expect(shadows.heroSoft, _hard(const Color(0x244A3B2E), 3));
      expect(shadows.card, _hard(const Color(0x334A3B2E), 3));
      expect(shadows.button, _hard(const Color(0xFF4A3B2E), 1.5));
      expect(
        shadows.outline,
        const Border.fromBorderSide(
          BorderSide(color: Color(0xFF4A3B2E), width: 1.5),
        ),
      );
    });

    test('dark shadows and outline use the dark shadow and line colours', () {
      const FieldNotesShadows shadows = FieldNotesShadows(
        FieldNotesColors.dark,
      );

      expect(shadows.emphasis, _hard(const Color(0xFF070504), 2));
      expect(shadows.hero, _hard(const Color(0x33000000), 3));
      expect(shadows.chip, _hard(const Color(0x29000000), 1.5));
      expect(
        shadows.outline,
        const Border.fromBorderSide(
          BorderSide(color: Color(0xFF9D8870), width: 1.5),
        ),
      );
    });
  });
}
