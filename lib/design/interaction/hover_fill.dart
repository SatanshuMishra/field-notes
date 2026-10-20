import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/interaction/hover_style.dart';
import 'package:flutter/widgets.dart';

class HoverFill extends StatelessWidget {
  const HoverFill({
    super.key,
    required this.hovered,
    required this.child,
    this.surface = FocusRingSurface.light,
    this.shape = HoverShape.rounded,
    this.borderRadius = BorderRadius.zero,
    this.position = DecorationPosition.foreground,
  });

  final bool hovered;
  final Widget child;
  final FocusRingSurface surface;
  final HoverShape shape;
  final BorderRadius borderRadius;
  final DecorationPosition position;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    position: position,
    decoration: HoverStyle.decoration(
      color: hovered ? HoverStyle.of(context, surface, shape) : null,
      shape: shape,
      borderRadius: borderRadius,
    ),
    child: child,
  );
}
