import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';

enum StickerButtonVariant { primary, secondary, danger }

class StickerButton extends StatelessWidget {
  const StickerButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = StickerButtonVariant.primary,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final StickerButtonVariant variant;
  final Widget? icon;

  bool get isEnabled => onPressed != null;

  @override
  Widget build(BuildContext context) {
    final _StickerButtonColors colors = _StickerButtonColors.of(variant);
    return Semantics(
      button: true,
      enabled: isEnabled,
      label: label,
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.5,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.background,
              border: Shapes.outline,
              borderRadius: Shapes.buttonBorderRadius,
              boxShadow: Shadows.button,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (icon != null) ...<Widget>[
                    icon!,
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: TypographyTokens.buttonSans
                        .copyWith(color: colors.foreground),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StickerButtonColors {
  const _StickerButtonColors({
    required this.background,
    required this.foreground,
  });

  final Color background;
  final Color foreground;

  static _StickerButtonColors of(StickerButtonVariant variant) {
    switch (variant) {
      case StickerButtonVariant.primary:
        return const _StickerButtonColors(
          background: Palette.coral,
          foreground: Palette.cardBright,
        );
      case StickerButtonVariant.secondary:
        return const _StickerButtonColors(
          background: Palette.cardBright,
          foreground: Palette.ink,
        );
      case StickerButtonVariant.danger:
        return const _StickerButtonColors(
          background: Palette.dangerSurface,
          foreground: Palette.danger,
        );
    }
  }
}
