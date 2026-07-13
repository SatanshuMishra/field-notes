import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';

class SettingsToggle extends StatelessWidget {
  const SettingsToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => onChanged?.call(!value) : null,
        child: SizedBox(
          width: 52,
          height: 30,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: value ? Palette.coral : Palette.panelTop,
              border: Shapes.outline,
              borderRadius: const BorderRadius.all(Radius.circular(15)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 150),
                alignment:
                    value ? Alignment.centerRight : Alignment.centerLeft,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: Palette.cardBright,
                    border: Shapes.outline,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(width: 22, height: 22),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
