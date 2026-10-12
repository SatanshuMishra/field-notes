import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:flutter/gestures.dart';
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
const double _neutralHoverOpacity = 0.08;

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

class _ActionPill extends StatefulWidget {
  const _ActionPill({
    required this.label,
    required this.onPressed,
    required this.tone,
  });

  final String label;
  final VoidCallback? onPressed;
  final SettingsActionTone tone;

  @override
  State<_ActionPill> createState() => _ActionPillState();
}

class _ActionPillState extends State<_ActionPill> {
  bool _hovered = false;

  void _hover(bool hovered) {
    if (hovered != _hovered) {
      setState(() => _hovered = hovered);
    }
  }

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final FieldNotesShadows shadows = context.shadows;
    final VoidCallback? onPressed = widget.onPressed;
    final bool enabled = onPressed != null;
    final BoxDecoration decoration = switch (widget.tone) {
      SettingsActionTone.neutral => BoxDecoration(
        color: enabled && _hovered
            ? Palette.coral.withValues(alpha: _neutralHoverOpacity)
            : null,
        border: Border.all(color: Palette.coral, width: Shapes.outlineWidth),
        borderRadius: _pillRadius,
      ),
      SettingsActionTone.primary => BoxDecoration(
        color: Palette.coral,
        border: shadows.outline,
        borderRadius: _pillRadius,
        boxShadow: shadows.control,
      ),
      SettingsActionTone.danger => BoxDecoration(
        color: Palette.danger,
        border: shadows.outline,
        borderRadius: _pillRadius,
        boxShadow: shadows.control,
      ),
    };
    final Color foreground = switch (widget.tone) {
      SettingsActionTone.neutral => colors.accentInk,
      SettingsActionTone.primary => Palette.onAccent,
      SettingsActionTone.danger => Palette.onAccent,
    };
    final Widget face = DecoratedBox(
      decoration: decoration,
      child: Padding(
        padding: _pillPadding,
        child: ExcludeSemantics(
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textStyles.labelSans.copyWith(
              fontSize: _pillFontSize,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
          onEnter: (PointerEnterEvent _) => _hover(true),
          onExit: (PointerExitEvent _) => _hover(false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onPressed,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _pillMinTapTarget),
              child: Center(
                widthFactor: 1,
                heightFactor: 1,
                child: FocusRing(
                  enabled: enabled,
                  onPressed: onPressed,
                  borderRadius: _pillRadius,
                  child: face,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
