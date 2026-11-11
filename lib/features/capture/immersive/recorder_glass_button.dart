import 'package:flutter/widgets.dart';

import 'package:field_notes/design/glass/glass_button.dart';

import 'recorder_inks.dart';

const double recorderGlassButtonFace = 40;

class RecorderGlassButton extends StatelessWidget {
  const RecorderGlassButton({
    super.key,
    required this.label,
    required this.glyph,
    required this.onPressed,
    this.toggled,
  });

  final String label;
  final Widget glyph;
  final VoidCallback? onPressed;
  final bool? toggled;

  @override
  Widget build(BuildContext context) {
    final RecorderInks inks = RecorderInks.of(context);
    return GlassCircleButton(
      tone: inks.glass,
      surface: inks.focus,
      face: recorderGlassButtonFace,
      label: label,
      glyph: glyph,
      onPressed: onPressed,
      toggled: toggled,
    );
  }
}
