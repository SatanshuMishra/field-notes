import 'package:flutter/material.dart';

import '../tokens/tokens.dart';

class SettingsSlider extends StatelessWidget {
  const SettingsSlider({
    super.key,
    required this.value,
    this.min = 1,
    this.max = 3,
    required this.onChanged,
    this.enabled = true,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ValueChanged<int>? handler = onChanged;
    return SliderTheme(
      data: const SliderThemeData(
        activeTrackColor: Palette.coral,
        inactiveTrackColor: Palette.muted,
        thumbColor: Palette.coral,
        overlayColor: Palette.panelCoralTint,
      ),
      child: Slider(
        value: value.toDouble(),
        min: min.toDouble(),
        max: max.toDouble(),
        divisions: max - min,
        onChanged: enabled && handler != null
            ? (double v) => handler(v.round())
            : null,
      ),
    );
  }
}
