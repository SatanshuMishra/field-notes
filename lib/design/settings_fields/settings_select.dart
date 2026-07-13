import 'package:flutter/material.dart';

import '../tokens/tokens.dart';

class SettingsSelectOption<T> {
  const SettingsSelectOption({
    required this.value,
    required this.label,
  });

  final T value;
  final String label;
}

class SettingsSelect<T> extends StatelessWidget {
  const SettingsSelect({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final List<SettingsSelectOption<T>> options;
  final T value;
  final ValueChanged<T>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final SettingsSelectOption<T> current =
        options.firstWhere((SettingsSelectOption<T> o) => o.value == value);
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: PopupMenuButton<T>(
        enabled: enabled && onChanged != null,
        initialValue: value,
        onSelected: onChanged,
        itemBuilder: (BuildContext context) => <PopupMenuEntry<T>>[
          for (final SettingsSelectOption<T> option in options)
            PopupMenuItem<T>(
              value: option.value,
              child: Text(option.label, style: TypographyTokens.bodySans),
            ),
        ],
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
                Text(current.label, style: TypographyTokens.bodySans),
                const SizedBox(width: 8),
                const Icon(Icons.expand_more, size: 18, color: Palette.ink),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
