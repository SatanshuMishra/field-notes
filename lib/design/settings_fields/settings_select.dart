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
    this.surface,
    this.foreground,
    this.border,
  });

  final List<SettingsSelectOption<T>> options;
  final T value;
  final ValueChanged<T>? onChanged;
  final bool enabled;
  final Color? surface;
  final Color? foreground;
  final Border? border;

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
            color: surface ?? Palette.cardBright,
            border: border ?? Shapes.outline,
            borderRadius: Shapes.buttonBorderRadius,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Flexible(
                  child: Text(
                    current.label,
                    overflow: TextOverflow.ellipsis,
                    style: TypographyTokens.bodySans
                        .copyWith(color: foreground),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.expand_more,
                  size: 18,
                  color: foreground ?? Palette.ink,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
