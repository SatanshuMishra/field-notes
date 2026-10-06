import 'package:flutter/widgets.dart';

import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/glass/glass_surface.dart';

const double recorderGlassButtonFace = 40;

const double _tapTarget = 48;
const double _disabledOpacity = 0.5;
const BorderRadius _round = BorderRadius.all(
  Radius.circular(recorderGlassButtonFace / 2),
);

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
    final VoidCallback? onPressed = this.onPressed;
    final bool enabled = onPressed != null;
    return Semantics(
      button: toggled == null,
      toggled: toggled,
      enabled: enabled,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox.square(
          dimension: _tapTarget,
          child: Center(
            child: FocusRing(
              enabled: enabled,
              onPressed: onPressed,
              surface: FocusRingSurface.dark,
              borderRadius: _round,
              child: Opacity(
                opacity: enabled ? 1 : _disabledOpacity,
                child: ExcludeSemantics(
                  child: GlassSurface(
                    tone: GlassTone.scene,
                    borderRadius: _round,
                    child: SizedBox.square(
                      dimension: recorderGlassButtonFace,
                      child: Center(child: glyph),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
