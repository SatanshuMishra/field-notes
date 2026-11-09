import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/interaction/hover_fill.dart';
import 'package:field_notes/design/interaction/min_target.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:flutter/material.dart';

import '../tokens/tokens.dart';

enum StickerGround { page, media }

enum StickerButtonVariant {
  primary,
  secondary,
  quiet,
  softAccent,
  danger,
  keep,
  stageSoft;

  Color inkOn(StickerGround ground, FieldNotesColors colors) => switch ((
    this,
    ground,
  )) {
    (StickerButtonVariant.primary, _) => Palette.onAccent,
    (StickerButtonVariant.secondary, _) => colors.ink,
    (StickerButtonVariant.quiet, StickerGround.page) => colors.inkSoft,
    (StickerButtonVariant.quiet, StickerGround.media) => Palette.mediaInk,
    (StickerButtonVariant.softAccent, StickerGround.page) => colors.accentInk,
    (StickerButtonVariant.softAccent, StickerGround.media) =>
      Palette.mediaPlayed,
    (StickerButtonVariant.danger, StickerGround.page) => colors.dangerInk,
    (StickerButtonVariant.danger, StickerGround.media) =>
      Palette.mediaDangerInk,
    (StickerButtonVariant.keep, StickerGround.page) => colors.mediaCtaInk,
    (StickerButtonVariant.keep, StickerGround.media) => Palette.mediaGround,
    (StickerButtonVariant.stageSoft, StickerGround.page) => colors.mediaCta,
    (StickerButtonVariant.stageSoft, StickerGround.media) => Palette.mediaInk,
  };
}

const BorderRadius _controlBorderRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusControl),
);

const EdgeInsets _capturePadding = EdgeInsets.symmetric(
  horizontal: 13,
  vertical: 10,
);

const EdgeInsets _confirmPadding = EdgeInsets.symmetric(
  horizontal: 16,
  vertical: 9,
);

const double _iconGap = 10;

const double _minTapTarget = 48;

const Border _clearEdge = Border.fromBorderSide(
  BorderSide(color: Colors.transparent, width: Shapes.outlineWidth),
);

const Color _softAccentHover = Color(0x24B8566A);
const Color _keepHoverOnMedia = Color(0xFFFFF4E2);
const double _quietHoverOpacityOnMedia = 0.12;
const double _stageSoftEdgeOpacity = 0.42;
const double _stageSoftHoverOpacity = 0.1;

class StickerButton extends StatelessWidget {
  const StickerButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = StickerButtonVariant.primary,
    this.icon,
    this.labelStyle,
    this.padTapTarget = false,
    this.focusSurface = FocusRingSurface.light,
    this.autofocus = false,
    this.ground = StickerGround.page,
    this.borderRadius,
  });

  final String label;
  final VoidCallback? onPressed;
  final StickerButtonVariant variant;
  final Widget? icon;
  final TextStyle? labelStyle;
  final bool padTapTarget;
  final FocusRingSurface focusSurface;
  final bool autofocus;
  final StickerGround ground;
  final BorderRadius? borderRadius;

  bool get isEnabled => onPressed != null;

  @override
  Widget build(BuildContext context) {
    final FieldNotesShadows shadows = context.shadows;
    final _StickerButtonStyle style = _StickerButtonStyle.of(
      variant,
      ground,
      context.colors,
      shadows,
      Theme.of(context).platform,
    );
    final BorderRadius radius = borderRadius ?? style.borderRadius;
    return Pressable(
      label: label,
      onPressed: onPressed,
      autofocus: autofocus,
      surface: focusSurface,
      borderRadius: radius,
      paintsHover: false,
      builder: (BuildContext context, bool hovered) {
        final Color? hoverBackground = style.hoverBackground;
        final Widget face = DecoratedBox(
          decoration: BoxDecoration(
            color: hovered && hoverBackground != null
                ? hoverBackground
                : style.background,
            border: style.edge,
            borderRadius: radius,
            boxShadow: style.shadow,
          ),
          child: HoverFill(
            hovered: hovered && hoverBackground == null,
            surface: style.hoverSurface,
            borderRadius: radius,
            position: DecorationPosition.background,
            child: Padding(
              padding: style.padding,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  if (icon != null) ...<Widget>[
                    icon!,
                    const SizedBox(width: _iconGap),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: (labelStyle ?? context.textStyles.buttonSans)
                          .copyWith(
                            color: hovered
                                ? style.hoverForeground ?? style.foreground
                                : style.foreground,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        final double? minHeight = style.minHeight;
        final Widget sized = minHeight == null
            ? face
            : ConstrainedBox(
                constraints: BoxConstraints(minHeight: minHeight),
                child: face,
              );
        return Opacity(
          opacity: isEnabled ? 1.0 : 0.5,
          child: padTapTarget ? _paddedTapTarget(sized) : sized,
        );
      },
    );
  }

  Widget _paddedTapTarget(Widget face) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: _minTapTarget,
        minHeight: _minTapTarget,
      ),
      child: Center(widthFactor: 1, heightFactor: 1, child: face),
    );
  }
}

class _StickerButtonStyle {
  const _StickerButtonStyle({
    required this.background,
    required this.foreground,
    required this.edge,
    required this.borderRadius,
    required this.padding,
    required this.shadow,
    this.hoverSurface = FocusRingSurface.light,
    this.hoverBackground,
    this.hoverForeground,
    this.minHeight,
  });

  final Color? background;
  final Color foreground;
  final Border edge;
  final BorderRadius borderRadius;
  final EdgeInsets padding;
  final List<BoxShadow>? shadow;
  final FocusRingSurface hoverSurface;
  final Color? hoverBackground;
  final Color? hoverForeground;
  final double? minHeight;

  static _StickerButtonStyle of(
    StickerButtonVariant variant,
    StickerGround ground,
    FieldNotesColors colors,
    FieldNotesShadows shadows,
    TargetPlatform platform,
  ) {
    final Color ink = variant.inkOn(ground, colors);
    final double buttonMinHeight = minButtonTargetOn(platform);
    switch (variant) {
      case StickerButtonVariant.primary:
        return _StickerButtonStyle(
          background: Palette.coral,
          foreground: ink,
          edge: shadows.outline,
          borderRadius: _controlBorderRadius,
          padding: _capturePadding,
          shadow: shadows.emphasis,
          hoverSurface: FocusRingSurface.dark,
        );
      case StickerButtonVariant.secondary:
        return _StickerButtonStyle(
          background: colors.cardWarm,
          foreground: ink,
          edge: shadows.outline,
          borderRadius: _controlBorderRadius,
          padding: _capturePadding,
          shadow: null,
          hoverSurface: FocusRingSurface.light,
        );
      case StickerButtonVariant.quiet:
        return _StickerButtonStyle(
          background: null,
          foreground: ink,
          edge: _clearEdge,
          borderRadius: _controlBorderRadius,
          padding: _capturePadding,
          shadow: null,
          hoverBackground: switch (ground) {
            StickerGround.page => colors.ink08,
            StickerGround.media => Palette.mediaInk.withValues(
              alpha: _quietHoverOpacityOnMedia,
            ),
          },
          hoverForeground: switch (ground) {
            StickerGround.page => colors.ink,
            StickerGround.media => ink,
          },
          minHeight: buttonMinHeight,
        );
      case StickerButtonVariant.softAccent:
        return _StickerButtonStyle(
          background: null,
          foreground: ink,
          edge: const Border.fromBorderSide(
            BorderSide(color: Palette.coral, width: Shapes.outlineWidth),
          ),
          borderRadius: _controlBorderRadius,
          padding: _capturePadding,
          shadow: null,
          hoverBackground: _softAccentHover,
          minHeight: buttonMinHeight,
        );
      case StickerButtonVariant.danger:
        return _StickerButtonStyle(
          background: null,
          foreground: ink,
          edge: Border.fromBorderSide(
            BorderSide(color: ink, width: Shapes.outlineWidth),
          ),
          borderRadius: Shapes.buttonBorderRadius,
          padding: _confirmPadding,
          shadow: null,
          hoverSurface: switch (ground) {
            StickerGround.page => FocusRingSurface.light,
            StickerGround.media => FocusRingSurface.dark,
          },
        );
      case StickerButtonVariant.keep:
        return _StickerButtonStyle(
          background: switch (ground) {
            StickerGround.page => colors.mediaCta,
            StickerGround.media => Palette.mediaInk,
          },
          foreground: ink,
          edge: _clearEdge,
          borderRadius: _controlBorderRadius,
          padding: _capturePadding,
          shadow: null,
          hoverBackground: switch (ground) {
            StickerGround.page => colors.mediaCtaHover,
            StickerGround.media => _keepHoverOnMedia,
          },
          minHeight: buttonMinHeight,
        );
      case StickerButtonVariant.stageSoft:
        return _StickerButtonStyle(
          background: null,
          foreground: ink,
          edge: Border.fromBorderSide(
            BorderSide(
              color: ink.withValues(alpha: _stageSoftEdgeOpacity),
              width: Shapes.outlineWidth,
            ),
          ),
          borderRadius: _controlBorderRadius,
          padding: _capturePadding,
          shadow: null,
          hoverBackground: ink.withValues(alpha: _stageSoftHoverOpacity),
          minHeight: buttonMinHeight,
        );
    }
  }
}
