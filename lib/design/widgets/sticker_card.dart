import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';

class StickerCard extends StatelessWidget {
  const StickerCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.surface = Palette.cardWarm,
    this.borderRadius = Shapes.cardBorderRadius,
    this.shadow = Shadows.card,
    this.rotationDegrees = 0,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color surface;
  final BorderRadius borderRadius;
  final List<BoxShadow> shadow;
  final double rotationDegrees;

  @override
  Widget build(BuildContext context) {
    final Widget sticker = DecoratedBox(
      decoration: BoxDecoration(
        color: surface,
        border: Shapes.outline,
        borderRadius: borderRadius,
        boxShadow: shadow,
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );

    if (rotationDegrees == 0) {
      return sticker;
    }

    return Transform.rotate(
      angle: rotationDegrees * math.pi / 180,
      child: sticker,
    );
  }
}
