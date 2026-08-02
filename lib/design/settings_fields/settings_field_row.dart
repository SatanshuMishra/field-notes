import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';

class SettingsFieldRow extends StatelessWidget {
  const SettingsFieldRow({
    super.key,
    required this.label,
    this.description,
    required this.control,
    this.labelColor,
    this.descriptionColor,
  });

  final String label;
  final String? description;
  final Widget control;
  final Color? labelColor;
  final Color? descriptionColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                style: TypographyTokens.labelSans.copyWith(color: labelColor),
              ),
              if (description != null) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  description!,
                  style: TypographyTokens.captionSans
                      .copyWith(color: descriptionColor ?? Palette.muted),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          flex: 2,
          child: Align(
            alignment: Alignment.centerRight,
            child: control,
          ),
        ),
      ],
    );
  }
}
