import 'package:field_notes/design/interaction/hover_fill.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:flutter/material.dart';

import '../format/clock_format.dart';
import '../tokens/tokens.dart';

class SettingsTimeField extends StatelessWidget {
  const SettingsTimeField({
    super.key,
    required this.value,
    required this.onTap,
    this.enabled = true,
    this.semanticLabel,
  });

  final TimeOfDay value;
  final VoidCallback? onTap;
  final bool enabled;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final String time = formatClock(context, value);
    final String? semanticLabel = this.semanticLabel;
    return Pressable(
      label: semanticLabel ?? time,
      value: semanticLabel == null ? null : time,
      onPressed: enabled ? onTap : null,
      borderRadius: Shapes.buttonBorderRadius,
      paintsHover: false,
      builder: (BuildContext context, bool hovered) => Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: kMinInteractiveDimension,
            minHeight: kMinInteractiveDimension,
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.colors.cardBright,
                border: context.shadows.outline,
                borderRadius: Shapes.buttonBorderRadius,
              ),
              child: HoverFill(
                hovered: hovered,
                borderRadius: Shapes.buttonBorderRadius,
                position: DecorationPosition.background,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(time, style: context.textStyles.bodySans),
                      const SizedBox(width: 8),
                      Icon(Icons.schedule, size: 18, color: context.colors.ink),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
