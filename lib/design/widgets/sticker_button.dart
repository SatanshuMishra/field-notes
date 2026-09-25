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
  });

  final String label;
  final VoidCallback? onPressed;
  final StickerButtonVariant variant;
  final Widget? icon;
  final TextStyle? labelStyle;
  final bool padTapTarget;

  bool get isEnabled => onPressed != null;

  @override
  Widget build(BuildContext context) {
    final _StickerButtonStyle style = _StickerButtonStyle.of(variant);
    final Widget face = DecoratedBox(
      decoration: BoxDecoration(
        color: style.background,
        border: Shapes.outline,
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
                style: (labelStyle ?? TypographyTokens.buttonSans)
                    .copyWith(color: style.foreground),
              ),
            ),
          ],
        ),
      ),
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
          child: padTapTarget ? _paddedTapTarget(face) : face,
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

  static _StickerButtonStyle of(StickerButtonVariant variant) {
    switch (variant) {
      case StickerButtonVariant.primary:
        return const _StickerButtonStyle(
          background: Palette.coral,
          foreground: Palette.onAccent,
          borderRadius: _controlBorderRadius,
          padding: _capturePadding,
          shadow: Shadows.emphasis,
        );
      case StickerButtonVariant.secondary:
        return const _StickerButtonStyle(
          background: Palette.cardWarm,
          foreground: Palette.ink,
          borderRadius: _controlBorderRadius,
          padding: _capturePadding,
          shadow: null,
        );
      case StickerButtonVariant.danger:
        return const _StickerButtonStyle(
          background: Palette.danger,
          foreground: Palette.onAccent,
          borderRadius: Shapes.buttonBorderRadius,
          padding: _confirmPadding,
          shadow: Shadows.control,
        );
    }
  }
}
