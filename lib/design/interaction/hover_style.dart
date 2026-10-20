import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:flutter/widgets.dart';

enum HoverShape { rounded, pill, circle }

abstract final class HoverStyle {
  static const double rowOpacity = 0.06;
  static const double pillOpacity = 0.08;
  static const double darkOpacity = 0.12;
  static const Color onDark = Color(0xFFFFFFFF);

  static Color fill(
    FocusRingSurface surface,
    HoverShape shape,
    FieldNotesColors colors,
  ) => switch (surface) {
    FocusRingSurface.dark => onDark.withValues(alpha: darkOpacity),
    FocusRingSurface.light => switch (shape) {
      HoverShape.pill => Palette.coral.withValues(alpha: pillOpacity),
      HoverShape.rounded ||
      HoverShape.circle => colors.ink.withValues(alpha: rowOpacity),
    },
  };

  static Color of(
    BuildContext context,
    FocusRingSurface surface,
    HoverShape shape,
  ) => fill(surface, shape, context.colors);

  static BoxDecoration decoration({
    required Color? color,
    required HoverShape shape,
    required BorderRadius borderRadius,
  }) => switch (shape) {
    HoverShape.circle => BoxDecoration(color: color, shape: BoxShape.circle),
    HoverShape.rounded ||
    HoverShape.pill => BoxDecoration(color: color, borderRadius: borderRadius),
  };
}
