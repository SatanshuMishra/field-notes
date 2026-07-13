import 'package:flutter/material.dart';

import '../tokens/tokens.dart';

class SettingsTimeField extends StatelessWidget {
  const SettingsTimeField({
    super.key,
    required this.value,
    required this.onTap,
    this.enabled = true,
  });

  final TimeOfDay value;
  final VoidCallback? onTap;
  final bool enabled;

  String get _formatted {
    final String hh = value.hour.toString().padLeft(2, '0');
    final String mm = value.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Palette.cardBright,
            border: Shapes.outline,
            borderRadius: Shapes.buttonBorderRadius,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(_formatted, style: TypographyTokens.bodySans),
                const SizedBox(width: 8),
                const Icon(Icons.schedule, size: 18, color: Palette.ink),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
