import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';

class OutlinedSurface extends StatelessWidget {
  const OutlinedSurface({
    super.key,
    required this.child,
    required this.borderRadius,
    required this.borderColor,
    this.borderWidth = Shapes.outlineWidth,
    this.color,
    this.boxShadow,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final Color borderColor;
  final double borderWidth;
  final Color? color;
  final List<BoxShadow>? boxShadow;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius,
        boxShadow: boxShadow,
      ),
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: ClipRRect(
          clipper: _InnerClipper(
            borderRadius: borderRadius,
            borderWidth: borderWidth,
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class _InnerClipper extends CustomClipper<RRect> {
  const _InnerClipper({required this.borderRadius, required this.borderWidth});

  final BorderRadius borderRadius;
  final double borderWidth;

  @override
  RRect getClip(Size size) {
    final Rect inner = (Offset.zero & size).deflate(borderWidth);
    return RRect.fromRectAndCorners(
      inner,
      topLeft: _inset(borderRadius.topLeft),
      topRight: _inset(borderRadius.topRight),
      bottomLeft: _inset(borderRadius.bottomLeft),
      bottomRight: _inset(borderRadius.bottomRight),
    );
  }

  Radius _inset(Radius radius) => Radius.elliptical(
    math.max(0, radius.x - borderWidth),
    math.max(0, radius.y - borderWidth),
  );

  @override
  bool shouldReclip(_InnerClipper oldClipper) =>
      oldClipper.borderRadius != borderRadius ||
      oldClipper.borderWidth != borderWidth;
}
