import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';

class SettingsStatusPill extends StatelessWidget {
  const SettingsStatusPill({
    super.key,
    required this.label,
    this.dotColor = Palette.statusAmber,
  });

  final String label;
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Palette.cardBright,
        border: Shapes.outline,
        borderRadius: Shapes.buttonBorderRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
              child: const SizedBox(width: 8, height: 8),
            ),
            const SizedBox(width: 8),
            Text(label, style: TypographyTokens.captionSans),
          ],
        ),
      ),
    );
  }
}
