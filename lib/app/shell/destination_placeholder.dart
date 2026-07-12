import 'package:flutter/material.dart';

import '../../design/tokens/tokens.dart';
import '../../design/widgets/widgets.dart';
import 'shell_destination.dart';

class DestinationPlaceholder extends StatelessWidget {
  const DestinationPlaceholder({super.key, required this.destination});

  final ShellDestination destination;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: ValueKey<ShellDestination>(destination),
      child: StickerCard(
        surface: Palette.cardBright,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(destination.icon, size: 40, color: Palette.ink),
            const SizedBox(height: 12),
            Text(destination.label, style: TypographyTokens.titleSerif),
          ],
        ),
      ),
    );
  }
}
