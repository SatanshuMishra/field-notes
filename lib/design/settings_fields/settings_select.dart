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

class SettingsSelect<T> extends StatefulWidget {
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
  State<SettingsSelect<T>> createState() => _SettingsSelectState<T>();
}

class _SettingsSelectState<T> extends State<SettingsSelect<T>> {
  final GlobalKey<PopupMenuButtonState<T>> _menuKey =
      GlobalKey<PopupMenuButtonState<T>>();

  bool get _canOpen => widget.enabled && widget.onChanged != null;

  void _openMenu() => _menuKey.currentState?.showButtonMenu();

  @override
  Widget build(BuildContext context) {
    final SettingsSelectOption<T> current = widget.options
        .firstWhere((SettingsSelectOption<T> o) => o.value == widget.value);
    return Opacity(
      opacity: widget.enabled ? 1.0 : 0.5,
      child: Semantics(
        container: true,
        button: true,
        enabled: _canOpen,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: _canOpen ? _openMenu : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: kMinInteractiveDimension,
              minHeight: kMinInteractiveDimension,
            ),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: PopupMenuButton<T>(
                key: _menuKey,
                enabled: _canOpen,
                initialValue: widget.value,
                onSelected: widget.onChanged,
                itemBuilder: (BuildContext context) => <PopupMenuEntry<T>>[
                  for (final SettingsSelectOption<T> option in widget.options)
                    PopupMenuItem<T>(
                      value: option.value,
                      child: Text(
                        option.label,
                        style: TypographyTokens.bodySans,
                      ),
                    ),
                ],
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: widget.surface ?? Palette.cardBright,
                    border: widget.border ?? Shapes.outline,
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
                        Flexible(
                          child: Text(
                            current.label,
                            overflow: TextOverflow.ellipsis,
                            style: TypographyTokens.bodySans
                                .copyWith(color: widget.foreground),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.expand_more,
                          size: 18,
                          color: widget.foreground ?? Palette.ink,
                        ),
                      ],
                    ),
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
