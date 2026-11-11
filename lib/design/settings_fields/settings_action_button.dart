import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/interaction/hover_fill.dart';
import 'package:field_notes/design/interaction/hover_style.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:flutter/material.dart';

import '../tokens/tokens.dart';
import '../widgets/sticker_button.dart';

import 'package:field_notes/design/interaction/min_target.dart';

const BorderRadius _pillRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusPill),
);
const EdgeInsets _pillPadding = EdgeInsets.symmetric(
  horizontal: 12 + Shapes.outlineWidth,
  vertical: 5 + Shapes.outlineWidth,
);
const double _pillFontSize = 12;
const double _leadingGap = 6;

enum SettingsActionTone { neutral, primary, danger }

class SettingsActionButton extends StatelessWidget {
  const SettingsActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.tone = SettingsActionTone.neutral,
    this.leading,
    this.minWidth = 0,
  });

  final String label;
  final VoidCallback? onPressed;
  final SettingsActionTone tone;
  final Widget? leading;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    final ShellLayout layout = resolveShellLayout(Theme.of(context).platform);
    return switch ((layout, tone)) {
      (ShellLayout.sidebar, SettingsActionTone.neutral) => _ActionPill(
        label: label,
        onPressed: onPressed,
        tone: _PillTone.neutral,
        leading: leading,
        minWidth: minWidth,
      ),
      (ShellLayout.sidebar, SettingsActionTone.primary) => _ActionPill(
        label: label,
        onPressed: onPressed,
        tone: _PillTone.primary,
        leading: leading,
        minWidth: minWidth,
      ),
      (ShellLayout.sidebar, SettingsActionTone.danger) => _atLeastMinWidth(
        StickerButton(
          label: label,
          onPressed: onPressed,
          padTapTarget: true,
          variant: StickerButtonVariant.danger,
          labelStyle: _pillLabelStyle(context),
          icon: leading,
        ),
      ),
      (ShellLayout.bottomBar, _) => _atLeastMinWidth(
        StickerButton(
          label: label,
          onPressed: onPressed,
          padTapTarget: true,
          icon: leading,
          variant: switch (tone) {
            SettingsActionTone.neutral => StickerButtonVariant.secondary,
            SettingsActionTone.primary => StickerButtonVariant.primary,
            SettingsActionTone.danger => StickerButtonVariant.danger,
          },
        ),
      ),
    };
  }

  Widget _atLeastMinWidth(Widget button) => minWidth == 0
      ? button
      : ConstrainedBox(
          constraints: BoxConstraints(minWidth: minWidth),
          child: button,
        );
}

TextStyle _pillLabelStyle(BuildContext context) => context.textStyles.labelSans
    .copyWith(fontSize: _pillFontSize, fontWeight: FontWeight.w600);

enum _PillTone { neutral, primary }

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.label,
    required this.onPressed,
    required this.tone,
    required this.minWidth,
    this.leading,
  });

  final String label;
  final VoidCallback? onPressed;
  final _PillTone tone;
  final double minWidth;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final FieldNotesShadows shadows = context.shadows;
    final bool enabled = onPressed != null;
    final FocusRingSurface hoverSurface = switch (tone) {
      _PillTone.neutral => FocusRingSurface.light,
      _PillTone.primary => FocusRingSurface.dark,
    };
    final Color foreground = switch (tone) {
      _PillTone.neutral => colors.accentInk,
      _PillTone.primary => Palette.onAccent,
    };
    return Pressable(
      label: label,
      onPressed: onPressed,
      shape: HoverShape.pill,
      borderRadius: _pillRadius,
      paintsHover: false,
      builder: (BuildContext context, bool hovered) {
        final Color? hoverFill = hovered
            ? HoverStyle.of(context, hoverSurface, HoverShape.pill)
            : null;
        final BoxDecoration decoration = switch (tone) {
          _PillTone.neutral => BoxDecoration(
            color: hoverFill,
            border: Border.all(
              color: Palette.coral,
              width: Shapes.outlineWidth,
            ),
            borderRadius: _pillRadius,
          ),
          _PillTone.primary => BoxDecoration(
            color: Palette.coral,
            border: shadows.outline,
            borderRadius: _pillRadius,
            boxShadow: shadows.control,
          ),
        };
        final Widget words = Text(
          label,
          textAlign: TextAlign.center,
          style: _pillLabelStyle(context).copyWith(color: foreground),
        );
        final Widget? leading = this.leading;
        final Widget text = Padding(
          padding: _pillPadding,
          child: leading == null
              ? words
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    leading,
                    const SizedBox(width: _leadingGap),
                    Flexible(child: words),
                  ],
                ),
        );
        return Opacity(
          opacity: enabled ? 1.0 : 0.5,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: minTargetOn(Theme.of(context).platform),
            ),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: minWidth),
                child: DecoratedBox(
                  decoration: decoration,
                  child: tone != _PillTone.primary
                      ? text
                      : HoverFill(
                          hovered: hovered,
                          surface: hoverSurface,
                          shape: HoverShape.pill,
                          borderRadius: _pillRadius,
                          position: DecorationPosition.background,
                          child: text,
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
