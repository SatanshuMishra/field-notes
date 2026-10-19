import 'package:flutter/widgets.dart';

import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/interaction/hover_fill.dart';
import 'package:field_notes/design/interaction/pressable.dart';

import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/widgets.dart';

const double _retryTarget = 48;
const double _retryChipHeight = 32;
const String retryMediaLabel = 'Try again';
const ValueKey<String> retryMediaKey = ValueKey<String>('media-retry');

class CorruptMediaPlaceholder extends StatelessWidget {
  const CorruptMediaPlaceholder({
    super.key,
    required this.label,
    this.width,
    this.height,
    this.borderRadius = Shapes.cardBorderRadius,
    this.onRetry,
  });

  final String label;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? retry = onRetry;
    final FieldNotesColors colors = context.colors;
    return CrossHatchPlaceholder(
      width: width,
      height: height,
      borderRadius: borderRadius,
      background: colors.dangerSurface,
      hatchColor: Palette.danger,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              textAlign: TextAlign.center,
              style: context.textStyles.captionSans.copyWith(
                color: colors.dangerInk,
              ),
            ),
            if (retry != null) _MediaRetryButton(onTap: retry),
          ],
        ),
      ),
    );
  }
}

class _MediaRetryButton extends StatelessWidget {
  const _MediaRetryButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return Pressable(
      label: retryMediaLabel,
      onPressed: onTap,
      borderRadius: Shapes.buttonBorderRadius,
      placement: FocusRingPlacement.edge,
      paintsHover: false,
      builder: (BuildContext context, bool hovered) => SizedBox(
        key: retryMediaKey,
        height: _retryTarget,
        child: Center(
          child: HoverFill(
            hovered: hovered,
            borderRadius: Shapes.buttonBorderRadius,
            child: Container(
              height: _retryChipHeight,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: colors.cardBright,
                border: context.shadows.outline,
                borderRadius: Shapes.buttonBorderRadius,
              ),
              child: Center(
                child: Text(
                  retryMediaLabel,
                  style: context.textStyles.captionSans,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NeutralMediaPlaceholder extends StatelessWidget {
  const NeutralMediaPlaceholder({
    super.key,
    this.width,
    this.height,
    this.borderRadius = Shapes.cardBorderRadius,
  });

  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return CrossHatchPlaceholder(
      width: width,
      height: height,
      borderRadius: borderRadius,
    );
  }
}
