import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/interaction/hover_fill.dart';
import 'package:field_notes/design/interaction/hover_style.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:flutter/material.dart';

import '../tokens/tokens.dart';
import '../widgets/sticker_button.dart';

const BorderRadius _pillRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusPill),
);
const EdgeInsets _pillPadding = EdgeInsets.symmetric(
  horizontal: 12 + Shapes.outlineWidth,
  vertical: 5 + Shapes.outlineWidth,
);
const double _pillFontSize = 12;
const double _pillMinTapTarget = 24;

enum SettingsActionTone { neutral, primary, danger }

class SettingsActionButton extends StatelessWidget {
  const SettingsActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.tone = SettingsActionTone.neutral,
  });

  final String label;
  final VoidCallback? onPressed;
  final SettingsActionTone tone;

  @override
  Widget build(BuildContext context) {
    return switch (resolveShellLayout(Theme.of(context).platform)) {
      ShellLayout.sidebar => _ActionPill(
        label: label,
        onPressed: onPressed,
        tone: tone,
      ),
      ShellLayout.bottomBar => StickerButton(
        label: label,
        onPressed: onPressed,
        padTapTarget: true,
        variant: switch (tone) {
          SettingsActionTone.neutral => StickerButtonVariant.secondary,
          SettingsActionTone.primary => StickerButtonVariant.primary,
          SettingsActionTone.danger => StickerButtonVariant.danger,
        },
      ),
    };
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.label,
    required this.onPressed,
    required this.tone,
  });

  final String label;
  final VoidCallback? onPressed;
  final SettingsActionTone tone;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final FieldNotesShadows shadows = context.shadows;
    final bool enabled = onPressed != null;
    final FocusRingSurface hoverSurface = switch (tone) {
      SettingsActionTone.neutral ||
      SettingsActionTone.danger => FocusRingSurface.light,
      SettingsActionTone.primary => FocusRingSurface.dark,
    };
    final Color foreground = switch (tone) {
      SettingsActionTone.neutral => colors.accentInk,
      SettingsActionTone.primary => Palette.onAccent,
      SettingsActionTone.danger => StickerButtonVariant.danger.inkOn(
        StickerGround.page,
        colors,
      ),
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
          SettingsActionTone.neutral => BoxDecoration(
            color: hoverFill,
            border: Border.all(
              color: Palette.coral,
              width: Shapes.outlineWidth,
            ),
            borderRadius: _pillRadius,
          ),
          SettingsActionTone.primary => BoxDecoration(
            color: Palette.coral,
            border: shadows.outline,
            borderRadius: _pillRadius,
            boxShadow: shadows.control,
          ),
          SettingsActionTone.danger => BoxDecoration(
            color: hoverFill,
            border: Border.all(color: foreground, width: Shapes.outlineWidth),
            borderRadius: _pillRadius,
          ),
        };
        final Widget text = Padding(
          padding: _pillPadding,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: context.textStyles.labelSans.copyWith(
              fontSize: _pillFontSize,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
        );
        return Opacity(
          opacity: enabled ? 1.0 : 0.5,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _pillMinTapTarget),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: decoration,
                child: tone != SettingsActionTone.primary
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
        );
      },
    );
  }
}
