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
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color surface;
  final BorderRadius borderRadius;
  final List<BoxShadow> shadow;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
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
  }
}
