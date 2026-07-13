import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';
import '../widgets/widgets.dart';

class Toast extends StatelessWidget {
  const Toast({
    super.key,
    required this.message,
    this.icon,
    this.surface = Palette.cardBright,
  });

  final String message;
  final Widget? icon;
  final Color surface;

  @override
  Widget build(BuildContext context) {
    return StickerCard(
      surface: surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      borderRadius: Shapes.buttonBorderRadius,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            icon!,
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(message, style: TypographyTokens.bodySans),
          ),
        ],
      ),
    );
  }
}
