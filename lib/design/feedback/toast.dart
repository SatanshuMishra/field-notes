import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../focus/focus_ring.dart';
import '../glass/glass.dart';
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

const FieldNotesTextStyles _pillTextStyles = FieldNotesTextStyles(
  FieldNotesColors.light,
);

final _DarkMetrics _phoneMetrics = (
  padHorizontal: 16,
  padVertical: 8,
  radius: Shapes.radiusXl,
  gap: 7,
  iconSize: 13,
  style: _pillTextStyles.caption11Sans,
  bottomInset: 84,
);

final _DarkMetrics _desktopMetrics = (
  padHorizontal: 20,
  padVertical: 10,
  radius: 22,
  gap: 8,
  iconSize: 15,
  style: _pillTextStyles.toastSans,
  bottomInset: 22,
);

_DarkMetrics _metricsFor(ToastScale scale) =>
    scale == ToastScale.desktop ? _desktopMetrics : _phoneMetrics;

ToastScale toastScaleFor(TargetPlatform platform) =>
    platform == TargetPlatform.macOS ? ToastScale.desktop : ToastScale.phone;

const Color _glassToastInk = Color.fromRGBO(251, 243, 228, 1);

const double _transientKeyboardGap = 16;
const double _riseOffset = 10;
const double toastActionMinTarget = 48;
const double _actionGap = 8;
const double _actionHorizontalPadding = 12;
const double _darkActionInset = 4;
const BorderRadius _actionRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusControl),
);
const EdgeInsets _lightPadding = EdgeInsets.symmetric(
  horizontal: 16,
  vertical: 10,
);
const EdgeInsets _lightPaddingWithAction = EdgeInsets.only(
  left: 16,
  right: 4,
  top: 4,
  bottom: 4,
);

@immutable
class ToastAction {
  const ToastAction({
    required this.label,
    required this.onPressed,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback onPressed;
  final String? semanticLabel;
}

class Toast extends StatelessWidget {
  const Toast({
    super.key,
    required this.message,
    this.icon,
    this.surface,
    this.variant = ToastVariant.light,
    this.scale = ToastScale.phone,
    this.action,
    this.opacity = 1,
  });

  final String message;
  final Widget? icon;
  final Color? surface;
  final ToastVariant variant;
  final ToastScale scale;
  final ToastAction? action;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    if (variant == ToastVariant.dark) {
      return _dark(context);
    }
    final ToastAction? action = this.action;
    return Opacity(
      opacity: opacity,
      child: StickerCard(
        surface: surface ?? context.colors.cardBright,
        padding: action == null ? _lightPadding : _lightPaddingWithAction,
        borderRadius: Shapes.buttonBorderRadius,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[icon!, const SizedBox(width: 8)],
            Flexible(child: Text(message, style: context.textStyles.bodySans)),
            if (action != null) ...<Widget>[
              const SizedBox(width: _actionGap),
              _ToastActionButton(action: action),
            ],
          ],
        ),
      ),
    );
  }

  Widget _dark(BuildContext context) {
    final Widget? icon = this.icon;
    final ToastAction? action = this.action;
    final _DarkMetrics metrics = _metricsFor(scale);
    return GlassSurface(
      tone: GlassTone.toast,
      opacity: opacity,
      borderRadius: BorderRadius.all(Radius.circular(metrics.radius)),
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
          if (icon != null) ...<Widget>[icon, SizedBox(width: metrics.gap)],
          Flexible(
            child: Text(
              message,
              style: metrics.style.copyWith(color: _glassToastInk),
            ),
          ),
          if (action != null) ...<Widget>[
            const SizedBox(width: _actionGap),
            _ToastActionButton(
              action: action,
              color: FieldNotesColors.light.waveLight,
              focusSurface: FocusRingSurface.dark,
            ),
          ],
        ],
      ),
    );
  }
}

class _ToastActionButton extends StatelessWidget {
  const _ToastActionButton({
    required this.action,
    this.color,
    this.focusSurface = FocusRingSurface.light,
  });

  final ToastAction action;
  final Color? color;
  final FocusRingSurface focusSurface;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: action.semanticLabel ?? action.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: action.onPressed,
        child: FocusRing(
          onPressed: action.onPressed,
          surface: focusSurface,
          borderRadius: _actionRadius,
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
                    style: context.textStyles.bodySans.copyWith(
                      color: color ?? context.colors.coralLink,
                      fontWeight: FontWeight.w600,
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

class ToastClearance extends StatefulWidget {
  const ToastClearance({super.key, required this.anchors, required this.child});

  final List<GlobalKey> anchors;
  final Widget child;

  static ValueListenable<double>? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_ToastClearanceScope>()?.bottom;

  @override
  State<ToastClearance> createState() => _ToastClearanceState();
}

class _ToastClearanceState extends State<ToastClearance> {
  final ValueNotifier<double> _bottom = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _measureAfterFrame();
  }

  @override
  void dispose() {
    final ValueNotifier<double> bottom = _bottom;
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      bottom.value = 0;
      bottom.dispose();
    });
    super.dispose();
  }

  void _measureAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (!mounted) {
        return;
      }
      _bottom.value = _measure();
      _measureAfterFrame();
    });
  }

  double _measure() {
    final RenderObject? overlay = Overlay.maybeOf(
      context,
      rootOverlay: true,
    )?.context.findRenderObject();
    if (overlay is! RenderBox || !overlay.hasSize) {
      return 0;
    }
    final double height = overlay.size.height;
    final double top = widget.anchors
        .map((GlobalKey anchor) => anchor.currentContext?.findRenderObject())
        .whereType<RenderBox>()
        .where((RenderBox box) => box.attached && box.hasSize)
        .map(
          (RenderBox box) =>
              box.localToGlobal(Offset.zero, ancestor: overlay).dy,
        )
        .fold<double>(height, math.min);
    return height - top;
  }

  @override
  Widget build(BuildContext context) {
    return _ToastClearanceScope(bottom: _bottom, child: widget.child);
  }
}

class _ToastClearanceScope extends InheritedWidget {
  const _ToastClearanceScope({required this.bottom, required super.child});

  final ValueListenable<double> bottom;

  @override
  bool updateShouldNotify(_ToastClearanceScope oldWidget) =>
      bottom != oldWidget.bottom;
}

final class ToastLift {
  ToastLift._(this.extra);

  final double extra;

  void remove() {
    _toastLifts.value = <ToastLift>[
      for (final ToastLift lift in _toastLifts.value)
        if (!identical(lift, this)) lift,
    ];
  }
}

final ValueNotifier<List<ToastLift>> _toastLifts =
    ValueNotifier<List<ToastLift>>(const <ToastLift>[]);

ToastLift registerToastLift(double extra) {
  final ToastLift lift = ToastLift._(extra);
  _toastLifts.value = <ToastLift>[..._toastLifts.value, lift];
  return lift;
}

double get activeToastLift => _toastLifts.value.fold<double>(
  0,
  (double highest, ToastLift lift) => math.max(highest, lift.extra),
);

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
  Future<void>? after,
}) {
  final OverlayState overlay = Overlay.of(context, rootOverlay: true);
  final FocusScopeNode? focusHost = Focus.maybeOf(
    context,
    scopeOk: true,
    createDependency: false,
  )?.nearestScope;
  final ToastScale scale = toastScaleFor(Theme.of(context).platform);
  final ValueListenable<double>? clearance = ToastClearance.maybeOf(context);
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
      clearance: clearance,
      focusHost: focusHost,
      lifetime:
          lifetime ?? (action == null ? kToastLifetime : kToastActionLifetime),
      action: action == null
          ? null
          : ToastAction(
              label: action.label,
              semanticLabel: action.semanticLabel,
              onPressed: () {
                finish();
                action.onPressed();
              },
            ),
      onFinished: finish,
    ),
  );
  void reveal() {
    if (!identical(_activeTransientToast, entry)) {
      return;
    }
    if (!overlay.mounted) {
      _activeTransientToast = null;
      return;
    }
    overlay.insert(entry);
  }

  _activeTransientToast = entry;
  if (after == null) {
    reveal();
    return;
  }
  unawaited(after.then<void>((_) => reveal(), onError: (Object _) => reveal()));
}

class _TransientToastLayer extends StatefulWidget {
  const _TransientToastLayer({
    required this.message,
    required this.glyph,
    required this.scale,
    required this.clearance,
    required this.focusHost,
    required this.lifetime,
    required this.action,
    required this.onFinished,
  });

  final String message;
  final IconStickerGlyph glyph;
  final ToastScale scale;
  final ValueListenable<double>? clearance;
  final FocusScopeNode? focusHost;
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
    _toastLifts.addListener(_liftChanged);
    _controller.forward();
  }

  @override
  void dispose() {
    _toastLifts.removeListener(_liftChanged);
    _lifetime.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _liftChanged() {
    if (SchedulerBinding.instance.schedulerPhase !=
        SchedulerPhase.persistentCallbacks) {
      setState(() {});
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  double _restingInset(BuildContext context) {
    final _DarkMetrics metrics = _metricsFor(widget.scale);
    if (widget.scale == ToastScale.desktop) {
      return metrics.bottomInset;
    }
    final MediaQueryData media = MediaQuery.of(context);
    final double gestureBar = math.max(
      media.padding.bottom,
      media.viewPadding.bottom,
    );
    return gestureBar + metrics.bottomInset + activeToastLift;
  }

  @override
  Widget build(BuildContext context) {
    final Widget toast = _toast();
    final ValueListenable<double>? clearance = widget.clearance;
    if (clearance == null) {
      return _placed(context, clearance: 0, toast: toast);
    }
    return ValueListenableBuilder<double>(
      valueListenable: clearance,
      child: toast,
      builder: (BuildContext context, double bottom, Widget? child) =>
          _placed(context, clearance: bottom, toast: child!),
    );
  }

  Widget _placed(
    BuildContext context, {
    required double clearance,
    required Widget toast,
  }) {
    final double keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Positioned(
      left: 0,
      right: 0,
      top: MediaQuery.paddingOf(context).top,
      bottom: 0,
      child: CustomSingleChildLayout(
        delegate: _ToastPlacement(
          bottom: math.max(
            _restingInset(context),
            math.max(keyboard, clearance) + _transientKeyboardGap,
          ),
        ),
        child: toast,
      ),
    );
  }

  FocusScopeNode? get _liveFocusHost {
    final FocusScopeNode? host = widget.focusHost;
    return host != null && (host.context?.mounted ?? false) ? host : null;
  }

  Widget _toast() {
    final _DarkMetrics metrics = _metricsFor(widget.scale);
    return IgnorePointer(
      ignoring: widget.action == null,
      child: Focus(
        parentNode: _liveFocusHost,
        canRequestFocus: false,
        skipTraversal: true,
        includeSemantics: false,
        child: Material(
          type: MaterialType.transparency,
          child: Center(
            child: AnimatedBuilder(
              animation: _rise,
              builder: (BuildContext context, Widget? child) =>
                  ExcludeSemantics(
                    excluding: _rise.value == 0,
                    child: Transform.translate(
                      offset: Offset(0, _riseOffset * (1 - _rise.value)),
                      child: Toast(
                        message: widget.message,
                        variant: ToastVariant.dark,
                        scale: widget.scale,
                        action: widget.action,
                        opacity: _rise.value,
                        icon: IconStickerGlyphIcon(
                          glyph: widget.glyph,
                          color: _glassToastInk,
                          size: metrics.iconSize,
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

class _ToastPlacement extends SingleChildLayoutDelegate {
  const _ToastPlacement({required this.bottom});

  final double bottom;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.tightFor(width: constraints.maxWidth);

  @override
  Offset getPositionForChild(Size size, Size childSize) =>
      Offset(0, math.max(0, size.height - bottom - childSize.height));

  @override
  bool shouldRelayout(_ToastPlacement oldDelegate) =>
      bottom != oldDelegate.bottom;
}
