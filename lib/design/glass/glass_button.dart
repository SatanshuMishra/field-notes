import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/glass/glass_surface.dart';
import 'package:field_notes/design/interaction/hover_fill.dart';
import 'package:field_notes/design/interaction/hover_style.dart';
import 'package:field_notes/design/interaction/pressable.dart';

const double _tapTarget = 48;
const double _disabledOpacity = 0.5;

class GlassCircleButton extends StatelessWidget {
  const GlassCircleButton({
    super.key,
    required this.tone,
    required this.face,
    required this.label,
    required this.glyph,
    required this.onPressed,
    this.toggled,
    this.tint,
    this.grouped = false,
  });

  final GlassTone tone;
  final double face;
  final String label;
  final Widget glyph;
  final VoidCallback? onPressed;
  final bool? toggled;
  final Color? tint;
  final bool grouped;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    final BorderRadius round = BorderRadius.circular(face / 2);
    return Pressable(
      label: label,
      toggled: toggled,
      onPressed: onPressed,
      surface: FocusRingSurface.dark,
      shape: HoverShape.circle,
      borderRadius: round,
      paintsHover: false,
      builder: (BuildContext context, bool hovered) => SizedBox.square(
        dimension: math.max(_tapTarget, face),
        child: Center(
          child: Opacity(
            opacity: enabled ? 1 : _disabledOpacity,
            child: HoverFill(
              hovered: hovered,
              surface: FocusRingSurface.dark,
              shape: HoverShape.circle,
              borderRadius: round,
              child: GlassSurface(
                tone: tone,
                tint: tint,
                grouped: grouped,
                borderRadius: round,
                child: SizedBox.square(
                  dimension: face,
                  child: Center(child: glyph),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
