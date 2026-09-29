import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';

enum StickerButtonVariant { primary, secondary, danger }

const BorderRadius _controlBorderRadius =
    BorderRadius.all(Radius.circular(Shapes.radiusControl));

const EdgeInsets _capturePadding =
    EdgeInsets.symmetric(horizontal: 13, vertical: 10);

const EdgeInsets _confirmPadding =
    EdgeInsets.symmetric(horizontal: 16, vertical: 9);

const double _iconGap = 10;

const double _minTapTarget = 48;

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
  });

  final String label;
  final VoidCallback? onPressed;
  final StickerButtonVariant variant;
  final Widget? icon;
  final TextStyle? labelStyle;
  final bool padTapTarget;
  final FocusRingSurface focusSurface;
  final bool autofocus;

  bool get isEnabled => onPressed != null;

  @override
  Widget build(BuildContext context) {
    final FieldNotesShadows shadows = context.shadows;
    final _StickerButtonStyle style = _StickerButtonStyle.of(
      variant,
      context.colors,
      shadows,
    );
    final Widget face = DecoratedBox(
      decoration: BoxDecoration(
        color: style.background,
        border: shadows.outline,
        borderRadius: style.borderRadius,
        boxShadow: style.shadow,
      ),
      child: Padding(
        padding: style.padding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              icon!,
              const SizedBox(width: _iconGap),
            ],
            ExcludeSemantics(
              child: Text(
                label,
                style: (labelStyle ?? context.textStyles.buttonSans)
                    .copyWith(color: style.foreground),
              ),
            ),
          ],
        ),
      ),
    );
    final Widget ringed = FocusRing(
      enabled: isEnabled,
      autofocus: autofocus,
      onPressed: onPressed,
      surface: focusSurface,
      borderRadius: style.borderRadius,
      child: face,
    );
    return Semantics(
      button: true,
      enabled: isEnabled,
      label: label,
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.5,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: padTapTarget ? _paddedTapTarget(ringed) : ringed,
        ),
      ),
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
    required this.borderRadius,
    required this.padding,
    required this.shadow,
  });

  final Color background;
  final Color foreground;
  final BorderRadius borderRadius;
  final EdgeInsets padding;
  final List<BoxShadow>? shadow;

  static _StickerButtonStyle of(
    StickerButtonVariant variant,
    FieldNotesColors colors,
    FieldNotesShadows shadows,
  ) {
    switch (variant) {
      case StickerButtonVariant.primary:
        return _StickerButtonStyle(
          background: Palette.coral,
          foreground: Palette.onAccent,
          borderRadius: _controlBorderRadius,
          padding: _capturePadding,
          shadow: shadows.emphasis,
        );
      case StickerButtonVariant.secondary:
        return _StickerButtonStyle(
          background: colors.cardWarm,
          foreground: colors.ink,
          borderRadius: _controlBorderRadius,
          padding: _capturePadding,
          shadow: null,
        );
      case StickerButtonVariant.danger:
        return _StickerButtonStyle(
          background: Palette.danger,
          foreground: Palette.onAccent,
          borderRadius: Shapes.buttonBorderRadius,
          padding: _confirmPadding,
          shadow: shadows.control,
        );
    }
  }
}
