import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:flutter/material.dart';

import '../tokens/tokens.dart';
import '../widgets/icon_sticker_button.dart';
import '../widgets/phone_sheet.dart';

const double settingsSelectSheetRowHeight = 48;

const EdgeInsets _sheetListPadding = EdgeInsets.fromLTRB(12, 6, 12, 8);
const EdgeInsets _sheetRowPadding = EdgeInsets.symmetric(horizontal: 12);
const double _sheetCheckSize = 18;
const double _sheetCheckGap = 12;
const BorderRadius _sheetRowRadius = BorderRadius.all(Radius.circular(12));

const TextStyle _sheetRowStyle = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 16,
  fontWeight: FontWeight.w400,
);

class SettingsSelectOption<T> {
  const SettingsSelectOption({required this.value, required this.label});

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
    this.focusSurface = FocusRingSurface.light,
  });

  final List<SettingsSelectOption<T>> options;
  final T value;
  final ValueChanged<T>? onChanged;
  final bool enabled;
  final Color? surface;
  final Color? foreground;
  final Border? border;
  final FocusRingSurface focusSurface;

  @override
  State<SettingsSelect<T>> createState() => _SettingsSelectState<T>();
}

class _SettingsSelectState<T> extends State<SettingsSelect<T>> {
  final GlobalKey<PopupMenuButtonState<T>> _menuKey =
      GlobalKey<PopupMenuButtonState<T>>();

  bool get _canOpen => widget.enabled && widget.onChanged != null;

  bool get _usesSheet =>
      resolveShellLayout(Theme.of(context).platform) == ShellLayout.bottomBar;

  void _open() {
    if (_usesSheet) {
      _openSheet();
      return;
    }
    _menuKey.currentState?.showButtonMenu();
  }

  Future<void> _openSheet() async {
    final SettingsSelectOption<T>? picked =
        await showPhoneSheet<SettingsSelectOption<T>>(
          context,
          builder: (BuildContext sheetContext) => _SettingsSelectSheet<T>(
            options: widget.options,
            value: widget.value,
            onPicked: (SettingsSelectOption<T> option) =>
                Navigator.of(sheetContext).pop(option),
          ),
        );
    if (picked == null || !mounted) {
      return;
    }
    widget.onChanged?.call(picked.value);
  }

  @override
  Widget build(BuildContext context) {
    final SettingsSelectOption<T> current = widget.options.firstWhere(
      (SettingsSelectOption<T> o) => o.value == widget.value,
    );
    final Widget field = DecoratedBox(
      decoration: BoxDecoration(
        color: widget.surface ?? context.colors.cardBright,
        border: widget.border ?? context.shadows.outline,
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
                style: context.textStyles.bodySans.copyWith(
                  color: widget.foreground,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.expand_more,
              size: 18,
              color: widget.foreground ?? context.colors.ink,
            ),
          ],
        ),
      ),
    );
    return Opacity(
      opacity: widget.enabled ? 1.0 : 0.5,
      child: Semantics(
        container: true,
        button: true,
        enabled: _canOpen,
        onTap: _usesSheet && _canOpen ? _open : null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: _canOpen ? _open : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: kMinInteractiveDimension,
              minHeight: kMinInteractiveDimension,
            ),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: FocusRing(
                enabled: _canOpen,
                onPressed: _open,
                surface: widget.focusSurface,
                borderRadius: Shapes.buttonBorderRadius,
                includeFocusSemantics: false,
                child: _usesSheet
                    ? field
                    : ExcludeFocus(
                        child: PopupMenuButton<T>(
                          key: _menuKey,
                          enabled: _canOpen,
                          initialValue: widget.value,
                          onSelected: widget.onChanged,
                          itemBuilder: (BuildContext context) =>
                              <PopupMenuEntry<T>>[
                                for (final SettingsSelectOption<T> option
                                    in widget.options)
                                  PopupMenuItem<T>(
                                    value: option.value,
                                    child: Text(
                                      option.label,
                                      style: context.textStyles.bodySans,
                                    ),
                                  ),
                              ],
                          child: field,
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

class _SettingsSelectSheet<T> extends StatelessWidget {
  const _SettingsSelectSheet({
    required this.options,
    required this.value,
    required this.onPicked,
  });

  final List<SettingsSelectOption<T>> options;
  final T value;
  final ValueChanged<SettingsSelectOption<T>> onPicked;

  @override
  Widget build(BuildContext context) {
    return PhoneSheet(
      child: Padding(
        padding: _sheetListPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final SettingsSelectOption<T> option in options)
              _SettingsSelectSheetRow(
                label: option.label,
                selected: option.value == value,
                autofocus: option.value == value,
                onTap: () => onPicked(option),
              ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSelectSheetRow extends StatelessWidget {
  const _SettingsSelectSheetRow({
    required this.label,
    required this.selected,
    required this.autofocus,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool autofocus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onTap,
        child: FocusRing(
          autofocus: autofocus,
          onPressed: onTap,
          includeFocusSemantics: false,
          placement: FocusRingPlacement.edge,
          borderRadius: _sheetRowRadius,
          child: SizedBox(
            height: settingsSelectSheetRowHeight,
            child: Padding(
              padding: _sheetRowPadding,
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: ExcludeSemantics(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _sheetRowStyle.copyWith(color: colors.ink),
                      ),
                    ),
                  ),
                  if (selected) ...<Widget>[
                    const SizedBox(width: _sheetCheckGap),
                    IconStickerGlyphIcon(
                      glyph: IconStickerGlyph.check,
                      color: colors.accentInk,
                      size: _sheetCheckSize,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
