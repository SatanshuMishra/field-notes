import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';
import '../widgets/widgets.dart';

class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final List<Widget> rows = <Widget>[];
    for (final Widget child in children) {
      rows.add(const DashedDivider());
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: child,
        ),
      );
    }
    return StickerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(title, style: TypographyTokens.eyebrowAccent),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: TypographyTokens.captionSans
                  .copyWith(color: Palette.muted),
            ),
          ],
          const SizedBox(height: 8),
          ...rows,
        ],
      ),
    );
  }
}
