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
    final VoidCallback? tap = enabled ? onTap : null;
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Semantics(
        container: true,
        button: true,
        enabled: tap != null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: tap,
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
                  color: Palette.cardBright,
                  border: Shapes.outline,
                  borderRadius: Shapes.buttonBorderRadius,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
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
          ),
        ),
      ),
    );
  }
}
