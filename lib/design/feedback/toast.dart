import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../motion/motion_tokens.dart';
import '../tokens/tokens.dart';
import '../widgets/icon_sticker_button.dart';
import '../widgets/widgets.dart';

enum ToastVariant { light, dark }

enum ToastScale { phone, desktop }

const Duration kToastLifetime = Duration(milliseconds: 1900);
const Duration kToastActionLifetime = Duration(seconds: 6);

typedef _DarkMetrics = ({
  double padHorizontal,
  double padVertical,
  double radius,
  double gap,
  double iconSize,
  TextStyle style,
  double bottomInset,
});

const _DarkMetrics _phoneMetrics = (
  padHorizontal: 16,
  padVertical: 8,
  radius: Shapes.radiusXl,
  gap: 7,
  iconSize: 13,
  style: TypographyTokens.caption11Sans,
  bottomInset: 84,
);

const _DarkMetrics _desktopMetrics = (
  padHorizontal: 20,
  padVertical: 10,
  radius: 22,
  gap: 8,
  iconSize: 15,
  style: TypographyTokens.toastSans,
  bottomInset: 22,
);

_DarkMetrics _metricsFor(ToastScale scale) =>
    scale == ToastScale.desktop ? _desktopMetrics : _phoneMetrics;

ToastScale toastScaleFor(TargetPlatform platform) =>
    platform == TargetPlatform.macOS ? ToastScale.desktop : ToastScale.phone;

const double _transientKeyboardGap = 16;
const double _riseOffset = 10;
const double toastActionMinTarget = 48;
const double _actionGap = 8;
const double _actionHorizontalPadding = 12;
const double _darkActionInset = 4;
const EdgeInsets _lightPadding =
    EdgeInsets.symmetric(horizontal: 16, vertical: 10);
const EdgeInsets _lightPaddingWithAction =
    EdgeInsets.only(left: 16, right: 4, top: 4, bottom: 4);

@immutable
class ToastAction {
  const ToastAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;
}

class Toast extends StatelessWidget {
  const Toast({
    super.key,
    required this.message,
    this.icon,
    this.surface = Palette.cardBright,
    this.variant = ToastVariant.light,
    this.scale = ToastScale.phone,
    this.action,
  });

  final String message;
  final Widget? icon;
  final Color surface;
  final ToastVariant variant;
  final ToastScale scale;
  final ToastAction? action;

  @override
  Widget build(BuildContext context) {
    if (variant == ToastVariant.dark) {
      return _dark();
    }
    final ToastAction? action = this.action;
    return StickerCard(
      surface: surface,
      padding: action == null ? _lightPadding : _lightPaddingWithAction,
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
          if (action != null) ...<Widget>[
            const SizedBox(width: _actionGap),
            _ToastActionButton(action: action),
          ],
        ],
      ),
    );
  }

  Widget _dark() {
    final Widget? icon = this.icon;
    final ToastAction? action = this.action;
    final _DarkMetrics metrics = _metricsFor(scale);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Palette.ink,
        borderRadius: BorderRadius.all(Radius.circular(metrics.radius)),
        boxShadow: Shadows.toastLift,
      ),
      child: Padding(
        padding: action == null
            ? EdgeInsets.symmetric(
                horizontal: metrics.padHorizontal,
                vertical: metrics.padVertical,
              )
            : EdgeInsets.only(
                left: metrics.padHorizontal,
                right: _darkActionInset,
                top: _darkActionInset,
                bottom: _darkActionInset,
              ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              icon,
              SizedBox(width: metrics.gap),
            ],
            Flexible(
              child: Text(
                message,
                style: metrics.style.copyWith(color: Palette.toastInk),
              ),
            ),
            if (action != null) ...<Widget>[
              const SizedBox(width: _actionGap),
              _ToastActionButton(action: action, color: Palette.waveLight),
            ],
          ],
        ),
      ),
    );
  }
}

class _ToastActionButton extends StatelessWidget {
  const _ToastActionButton({
    required this.action,
    this.color = Palette.coralLink,
  });

  final ToastAction action;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: action.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: action.onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: toastActionMinTarget,
            minHeight: toastActionMinTarget,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _actionHorizontalPadding,
            ),
            child: Center(
              widthFactor: 1,
              child: ExcludeSemantics(
                child: Text(
                  action.label,
                  style: TypographyTokens.bodySans.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
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

OverlayEntry? _activeTransientToast;

void dismissTransientToast() {
  final OverlayEntry? active = _activeTransientToast;
  _activeTransientToast = null;
  if (active != null && active.mounted) {
    active.remove();
  }
}

void showTransientToast(
  BuildContext context,
  String message, {
  IconStickerGlyph glyph = IconStickerGlyph.check,
  ToastAction? action,
  Duration? lifetime,
}) {
  final OverlayState overlay = Overlay.of(context, rootOverlay: true);
  final ToastScale scale = toastScaleFor(Theme.of(context).platform);
  dismissTransientToast();
  late final OverlayEntry entry;
  void finish() {
    if (identical(_activeTransientToast, entry)) {
      dismissTransientToast();
    }
  }

  entry = OverlayEntry(
    builder: (BuildContext overlayContext) => _TransientToastLayer(
      message: message,
      glyph: glyph,
      scale: scale,
      lifetime:
          lifetime ?? (action == null ? kToastLifetime : kToastActionLifetime),
      action: action == null
          ? null
          : ToastAction(
              label: action.label,
              onPressed: () {
                finish();
                action.onPressed();
              },
            ),
      onFinished: finish,
    ),
  );
  _activeTransientToast = entry;
  overlay.insert(entry);
}

class _TransientToastLayer extends StatefulWidget {
  const _TransientToastLayer({
    required this.message,
    required this.glyph,
    required this.scale,
    required this.lifetime,
    required this.action,
    required this.onFinished,
  });

  final String message;
  final IconStickerGlyph glyph;
  final ToastScale scale;
  final Duration lifetime;
  final ToastAction? action;
  final VoidCallback onFinished;

  @override
  State<_TransientToastLayer> createState() => _TransientToastLayerState();
}

class _TransientToastLayerState extends State<_TransientToastLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.toastRise,
  );
  late final Animation<double> _rise = CurvedAnimation(
    parent: _controller,
    curve: Motion.fadeCurve,
  );
  late final Timer _lifetime;

  @override
  void initState() {
    super.initState();
    _lifetime = Timer(widget.lifetime, widget.onFinished);
    _controller.forward();
  }

  @override
  void dispose() {
    _lifetime.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _DarkMetrics metrics = _metricsFor(widget.scale);
    return Positioned(
      left: 0,
      right: 0,
      bottom: math.max(
        metrics.bottomInset,
        MediaQuery.viewInsetsOf(context).bottom + _transientKeyboardGap,
      ),
      child: IgnorePointer(
        ignoring: widget.action == null,
        child: Material(
          type: MaterialType.transparency,
          child: Center(
            child: FadeTransition(
              opacity: _rise,
              child: AnimatedBuilder(
                animation: _rise,
                builder: (BuildContext context, Widget? child) =>
                    Transform.translate(
                  offset: Offset(0, _riseOffset * (1 - _rise.value)),
                  child: child,
                ),
                child: Toast(
                  message: widget.message,
                  variant: ToastVariant.dark,
                  scale: widget.scale,
                  action: widget.action,
                  icon: IconStickerGlyphIcon(
                    glyph: widget.glyph,
                    color: Palette.toastInk,
                    size: metrics.iconSize,
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
