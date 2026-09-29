import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'field_notes_colors.dart';
import 'shapes.dart';

@immutable
class FieldNotesShadows {
  const FieldNotesShadows(this.colors);

  final FieldNotesColors colors;

  List<BoxShadow> get chip => _hard(colors.shadowTint(0x29), 1.5);

  List<BoxShadow> get cellFilled => _hard(colors.shadowTint(0x2E), 1.5);

  List<BoxShadow> get control => _hard(colors.shadow, 1.5);

  List<BoxShadow> get cardDefault => _hard(colors.shadowTint(0x29), 2);

  List<BoxShadow> get emphasis => _hard(colors.shadow, 2);

  List<BoxShadow> get phoneAction => _hard(colors.shadow, 2.5);

  List<BoxShadow> get hero => _hard(colors.shadowTint(0x33), 3);

  List<BoxShadow> get heroSoft => _hard(colors.shadowTint(0x24), 3);

  List<BoxShadow> get card => hero;

  List<BoxShadow> get button => control;

  Border get outline => Border.fromBorderSide(
    BorderSide(color: colors.line, width: Shapes.outlineWidth),
  );

  static List<BoxShadow> _hard(Color color, double offset) =>
      List<BoxShadow>.unmodifiable(<BoxShadow>[
        BoxShadow(
          color: color,
          offset: Offset(offset, offset),
          blurRadius: 0,
          spreadRadius: 0,
        ),
      ]);
}
