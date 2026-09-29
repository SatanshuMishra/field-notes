import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';

class StickerCard extends StatelessWidget {
  const StickerCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.surface,
    this.borderRadius = Shapes.cardBorderRadius,
    this.shadow,
    this.rotationDegrees = 0,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? surface;
  final BorderRadius borderRadius;
  final List<BoxShadow>? shadow;
  final double rotationDegrees;

  @override
  Widget build(BuildContext context) {
    final FieldNotesShadows shadows = context.shadows;
    final Widget sticker = DecoratedBox(
      decoration: BoxDecoration(
        color: surface ?? context.colors.cardWarm,
        border: shadows.outline,
        borderRadius: borderRadius,
        boxShadow: shadow ?? shadows.card,
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
