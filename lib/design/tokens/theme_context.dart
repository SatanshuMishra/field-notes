import 'package:flutter/widgets.dart';

import 'field_notes_colors.dart';
import 'field_notes_shadows.dart';
import 'field_notes_text_styles.dart';

extension FieldNotesThemeContext on BuildContext {
  FieldNotesColors get colors => FieldNotesColors.of(this);

  FieldNotesTextStyles get textStyles => FieldNotesTextStyles(colors);

  FieldNotesShadows get shadows => FieldNotesShadows(colors);
}
