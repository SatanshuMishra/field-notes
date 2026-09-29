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
    return Semantics(
      container: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    label,
                    style: context.textStyles.labelSans.copyWith(
                      color: labelColor,
                    ),
                  ),
                  if (description != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      description!,
                      style: context.textStyles.captionSans.copyWith(
                        color: descriptionColor ?? context.colors.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Semantics(container: true, child: control),
            ),
          ),
        ],
      ),
    );
  }
}
