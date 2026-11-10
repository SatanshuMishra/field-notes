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
    this.bleed = EdgeInsets.zero,
    this.fillKey,
  });

  final bool hovered;
  final Widget child;
  final FocusRingSurface surface;
  final HoverShape shape;
  final BorderRadius borderRadius;
  final DecorationPosition position;
  final EdgeInsets bleed;
  final Key? fillKey;

  @override
  Widget build(BuildContext context) {
    final Decoration decoration = HoverStyle.decoration(
      color: hovered ? HoverStyle.of(context, surface, shape) : null,
      shape: shape,
      borderRadius: borderRadius,
    );
    if (bleed == EdgeInsets.zero) {
      return DecoratedBox(
        key: fillKey,
        position: position,
        decoration: decoration,
        child: child,
      );
    }
    final Widget fill = Positioned(
      left: -bleed.left,
      top: -bleed.top,
      right: -bleed.right,
      bottom: -bleed.bottom,
      child: IgnorePointer(
        child: DecoratedBox(key: fillKey, decoration: decoration),
      ),
    );
    return Stack(
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: switch (position) {
        DecorationPosition.background => <Widget>[fill, child],
        DecorationPosition.foreground => <Widget>[child, fill],
      },
    );
  }
}
