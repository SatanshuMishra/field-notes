import 'package:flutter/widgets.dart';

import 'package:field_notes/design/focus/focus_ring.dart';
import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/widgets.dart';

const double _retryTarget = 48;
const double _retryChipHeight = 32;
const String retryMediaLabel = 'Try again';
const ValueKey<String> retryMediaKey = ValueKey<String>('media-retry');
const double _retryFocusWidth = 3;

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
    final FieldNotesColors colors = context.colors;
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
                key: _focused ? focusRingKey : null,
                height: _retryChipHeight,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: colors.cardBright,
                  border: _focused
                      ? Border.fromBorderSide(
                          BorderSide(
                            color: colors.ink,
                            width: _retryFocusWidth,
                          ),
                        )
                      : context.shadows.outline,
                  borderRadius: Shapes.buttonBorderRadius,
                ),
                child: Center(
                  child: ExcludeSemantics(
                    child: Text(
                      retryMediaLabel,
                      style: context.textStyles.captionSans,
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
