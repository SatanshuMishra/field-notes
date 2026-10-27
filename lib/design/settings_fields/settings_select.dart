import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/interaction/hover_fill.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:field_notes/design/widgets/anchored_dropdown.dart';
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

const TextStyle _sidebarValueStyle = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 13,
  fontWeight: FontWeight.w400,
);
const BorderRadius _sidebarFieldRadius = BorderRadius.all(Radius.circular(9));
const EdgeInsets _sidebarFieldPadding = EdgeInsets.symmetric(
  horizontal: 10 + Shapes.outlineWidth,
  vertical: 4 + Shapes.outlineWidth,
);
const double _sidebarChevronSize = 14;
const double _sidebarChevronGap = 7;
const double _macosMinTapTarget = 28;
const double _windowsMinTapTarget = 40;

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
    this.semanticLabel,
  });

  final List<SettingsSelectOption<T>> options;
  final T value;
  final ValueChanged<T>? onChanged;
  final bool enabled;
  final Color? surface;
  final Color? foreground;
  final Border? border;
  final FocusRingSurface focusSurface;
  final String? semanticLabel;

  @override
  State<SettingsSelect<T>> createState() => _SettingsSelectState<T>();
}

class _SettingsSelectState<T> extends State<SettingsSelect<T>> {
  bool get _canOpen => widget.enabled && widget.onChanged != null;

  bool get _usesSheet =>
      resolveShellLayout(Theme.of(context).platform) == ShellLayout.bottomBar;

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

  void _pick(T value) {
    if (_canOpen) {
      widget.onChanged?.call(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final SettingsSelectOption<T> current = widget.options.firstWhere(
      (SettingsSelectOption<T> o) => o.value == widget.value,
    );
    final bool sheet = _usesSheet;
    final BorderRadius radius = sheet
        ? Shapes.buttonBorderRadius
        : _sidebarFieldRadius;
    final double minTapTarget = switch (Theme.of(context).platform) {
      TargetPlatform.macOS => _macosMinTapTarget,
      TargetPlatform.windows => _windowsMinTapTarget,
      _ => kMinInteractiveDimension,
    };
    final String? semanticLabel = widget.semanticLabel;
    Widget trigger(VoidCallback open) => Pressable(
      includeFocusSemantics: false,
      label: semanticLabel ?? current.label,
      value: semanticLabel == null ? null : current.label,
      onPressed: _canOpen ? open : null,
      surface: widget.focusSurface,
      borderRadius: radius,
      paintsHover: false,
      builder: (BuildContext context, bool hovered) => Opacity(
        opacity: widget.enabled ? 1.0 : 0.5,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: minTapTarget,
            minHeight: minTapTarget,
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: _field(context, current, sheet, radius, hovered),
          ),
        ),
      ),
    );
    if (sheet) {
      return trigger(_openSheet);
    }
    return AnchoredDropdown<T>(
      choices: <AnchoredDropdownChoice<T>>[
        for (final SettingsSelectOption<T> option in widget.options)
          AnchoredDropdownChoice<T>(value: option.value, label: option.label),
      ],
      current: widget.value,
      onSelected: _pick,
      widensToFitChoices: true,
      builder: (BuildContext context, bool open, VoidCallback toggle) =>
          trigger(toggle),
    );
  }

  Widget _field(
    BuildContext context,
    SettingsSelectOption<T> current,
    bool sheet,
    BorderRadius radius,
    bool hovered,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: widget.surface ?? context.colors.cardBright,
        border: widget.border ?? context.shadows.outline,
        borderRadius: radius,
      ),
      child: HoverFill(
        hovered: hovered,
        surface: widget.focusSurface,
        borderRadius: radius,
        position: DecorationPosition.background,
        child: Padding(
          padding: sheet
              ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
              : _sidebarFieldPadding,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Flexible(
                child: Text(
                  current.label,
                  overflow: TextOverflow.ellipsis,
                  style: sheet
                      ? context.textStyles.bodySans.copyWith(
                          color: widget.foreground,
                        )
                      : _sidebarValueStyle.copyWith(
                          color: widget.foreground ?? context.colors.ink,
                        ),
                ),
              ),
              SizedBox(width: sheet ? 8 : _sidebarChevronGap),
              Icon(
                Icons.expand_more,
                size: sheet ? 18 : _sidebarChevronSize,
                color: widget.foreground ?? context.colors.ink,
              ),
            ],
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
    return Pressable(
      includeFocusSemantics: false,
      label: label,
      selected: selected,
      autofocus: autofocus,
      onPressed: onTap,
      placement: FocusRingPlacement.edge,
      borderRadius: _sheetRowRadius,
      excludeSemantics: false,
      child: Semantics(
        inMutuallyExclusiveGroup: true,
        child: ExcludeSemantics(
          child: SizedBox(
            height: settingsSelectSheetRowHeight,
            child: Padding(
              padding: _sheetRowPadding,
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _sheetRowStyle.copyWith(color: colors.ink),
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
