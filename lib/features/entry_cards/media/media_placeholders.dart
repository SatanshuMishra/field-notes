import 'package:flutter/widgets.dart';

import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/widgets.dart';

const double _retryTarget = 48;
const double _retryChipHeight = 32;
const String retryMediaLabel = 'Try again';
const ValueKey<String> retryMediaKey = ValueKey<String>('media-retry');
const Border _retryFocusOutline = Border.fromBorderSide(
  BorderSide(color: Palette.ink, width: 3),
);

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
    return CrossHatchPlaceholder(
      width: width,
      height: height,
      borderRadius: borderRadius,
      background: Palette.dangerSurface,
      hatchColor: Palette.danger,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              textAlign: TextAlign.center,
              style:
                  TypographyTokens.captionSans.copyWith(color: Palette.danger),
            ),
            if (retry != null) _MediaRetryButton(onTap: retry),
          ],
        ),
      ),
    );
  }
}

class _MediaRetryButton extends StatefulWidget {
  const _MediaRetryButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_MediaRetryButton> createState() => _MediaRetryButtonState();
}

class _MediaRetryButtonState extends State<_MediaRetryButton> {
  bool _focused = false;

  void _onFocusHighlight(bool focused) {
    if (!mounted || focused == _focused) {
      return;
    }
    setState(() => _focused = focused);
  }

  Object? _activate(Intent intent) {
    widget.onTap();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: _activate),
      },
      onShowFocusHighlight: _onFocusHighlight,
      child: Semantics(
        container: true,
        button: true,
        enabled: true,
        label: retryMediaLabel,
        child: GestureDetector(
          key: retryMediaKey,
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: SizedBox(
            height: _retryTarget,
            child: Center(
              child: Container(
                height: _retryChipHeight,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Palette.cardBright,
                  border: _focused ? _retryFocusOutline : Shapes.outline,
                  borderRadius: Shapes.buttonBorderRadius,
                ),
                child: const Center(
                  child: ExcludeSemantics(
                    child: Text(
                      retryMediaLabel,
                      style: TypographyTokens.captionSans,
                    ),
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
