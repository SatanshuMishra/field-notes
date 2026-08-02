import 'package:flutter/widgets.dart';

import '../motion/motion_tokens.dart';
import '../tokens/tokens.dart';
import '../widgets/icon_sticker_button.dart';
import '../widgets/widgets.dart';

enum ToastVariant { light, dark }

const Duration kToastLifetime = Duration(milliseconds: 1900);

const double _darkPadHorizontal = 16;
const double _darkPadVertical = 8;
const double _darkGap = 7;
const double _darkIconSize = 13;
const double _transientBottomInset = 84;
const double _riseOffset = 10;

class Toast extends StatelessWidget {
  const Toast({
    super.key,
    required this.message,
    this.icon,
    this.surface = Palette.cardBright,
    this.variant = ToastVariant.light,
  });

  final String message;
  final Widget? icon;
  final Color surface;
  final ToastVariant variant;

  @override
  Widget build(BuildContext context) {
    if (variant == ToastVariant.dark) {
      return _dark();
    }
    return StickerCard(
      surface: surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      borderRadius: Shapes.buttonBorderRadius,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            icon!,
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(message, style: TypographyTokens.bodySans),
          ),
        ],
      ),
    );
  }

  Widget _dark() {
    final Widget? icon = this.icon;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Palette.ink,
        borderRadius: BorderRadius.all(Radius.circular(Shapes.radiusXl)),
        boxShadow: Shadows.toastLift,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _darkPadHorizontal,
          vertical: _darkPadVertical,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              icon,
              const SizedBox(width: _darkGap),
            ],
            Flexible(
              child: Text(
                message,
                style: TypographyTokens.caption11Sans.copyWith(
                  color: Palette.toastInk,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

OverlayEntry? _activeTransientToast;

void dismissTransientToast() {
  final OverlayEntry? active = _activeTransientToast;
  _activeTransientToast = null;
  if (active != null && active.mounted) {
    active.remove();
  }
}

void showTransientToast(BuildContext context, String message) {
  final OverlayState overlay = Overlay.of(context, rootOverlay: true);
  dismissTransientToast();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (BuildContext overlayContext) => _TransientToastLayer(
      message: message,
      onFinished: () {
        if (identical(_activeTransientToast, entry)) {
          dismissTransientToast();
        }
      },
    ),
  );
  _activeTransientToast = entry;
  overlay.insert(entry);
}

class _TransientToastLayer extends StatefulWidget {
  const _TransientToastLayer({required this.message, required this.onFinished});

  final String message;
  final VoidCallback onFinished;

  @override
  State<_TransientToastLayer> createState() => _TransientToastLayerState();
}

class _TransientToastLayerState extends State<_TransientToastLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: kToastLifetime,
  );
  late final Animation<double> _rise = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      0,
      Motion.toastRise.inMilliseconds / kToastLifetime.inMilliseconds,
      curve: Motion.fadeCurve,
    ),
  );

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener(_onStatus);
    _controller.forward();
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.onFinished();
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: _transientBottomInset,
      child: IgnorePointer(
        child: Center(
          child: FadeTransition(
            opacity: _rise,
            child: AnimatedBuilder(
              animation: _rise,
              builder: (BuildContext context, Widget? child) => Transform.translate(
                offset: Offset(0, _riseOffset * (1 - _rise.value)),
                child: child,
              ),
              child: Toast(
                message: widget.message,
                variant: ToastVariant.dark,
                icon: const IconStickerGlyphIcon(
                  glyph: IconStickerGlyph.check,
                  color: Palette.toastInk,
                  size: _darkIconSize,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
