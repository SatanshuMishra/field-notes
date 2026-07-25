import 'package:flutter/widgets.dart';

import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/widgets.dart';

class CorruptMediaPlaceholder extends StatelessWidget {
  const CorruptMediaPlaceholder({
    super.key,
    required this.label,
    this.width,
    this.height,
    this.borderRadius = Shapes.cardBorderRadius,
  });

  final String label;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return CrossHatchPlaceholder(
      width: width,
      height: height,
      borderRadius: borderRadius,
      background: Palette.dangerSurface,
      hatchColor: Palette.danger,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TypographyTokens.captionSans.copyWith(color: Palette.danger),
        ),
      ),
    );
  }
}

class NeutralMediaPlaceholder extends StatelessWidget {
  const NeutralMediaPlaceholder({
    super.key,
    this.width,
    this.height,
    this.borderRadius = Shapes.cardBorderRadius,
  });

  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return CrossHatchPlaceholder(
      width: width,
      height: height,
      borderRadius: borderRadius,
    );
  }
}
