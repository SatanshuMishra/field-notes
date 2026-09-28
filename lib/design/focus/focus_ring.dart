import 'package:field_notes/design/tokens/palette.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

const ValueKey<String> focusRingKey = ValueKey<String>('focus-ring');

enum FocusRingSurface {
  light(color: Palette.focusRing, width: 3),
  dark(color: Palette.focusRingOnDark, width: 2);

  const FocusRingSurface({required this.color, required this.width});

  final Color color;
  final double width;
}

enum FocusRingPlacement { outside, edge }

const Map<ShortcutActivator, Intent> _activators = <ShortcutActivator, Intent>{
  SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
  SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
  SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
};

class FocusRing extends StatefulWidget {
  const FocusRing({
    super.key,
    required this.onPressed,
    required this.child,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
    this.surface = FocusRingSurface.light,
    this.borderRadius = BorderRadius.zero,
    this.includeFocusSemantics = true,
    this.placement = FocusRingPlacement.outside,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final bool enabled;
  final bool autofocus;
  final FocusNode? focusNode;
  final FocusRingSurface surface;
  final BorderRadius borderRadius;
  final bool includeFocusSemantics;
  final FocusRingPlacement placement;

  double get reach =>
      placement == FocusRingPlacement.outside ? 2 + surface.width : 0;

  @override
  State<FocusRing> createState() => _FocusRingState();
}

class _FocusRingState extends State<FocusRing> {
  bool _highlighted = false;

  late final Map<Type, Action<Intent>> _actions = <Type, Action<Intent>>{
    ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: _activate),
  };

  Object? _activate(ActivateIntent intent) {
    widget.onPressed?.call();
    return null;
  }

  void _handleShowFocusHighlight(bool highlighted) {
    if (highlighted != _highlighted) {
      setState(() => _highlighted = highlighted);
    }
    if (highlighted && widget.reach > 0) {
      WidgetsBinding.instance.addPostFrameCallback(_revealRing);
    }
  }

  void _revealRing(Duration timeStamp) {
    if (!mounted) {
      return;
    }
    final RenderObject? box = context.findRenderObject();
    if (box is RenderBox && box.attached && box.hasSize) {
      box.showOnScreen(rect: (Offset.zero & box.size).inflate(widget.reach));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      enabled: widget.enabled,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      includeFocusSemantics: widget.includeFocusSemantics,
      shortcuts: _activators,
      actions: widget.onPressed == null ? null : _actions,
      onShowFocusHighlight: _handleShowFocusHighlight,
      child: Stack(
        alignment: Alignment.topLeft,
        fit: StackFit.passthrough,
        clipBehavior: Clip.none,
        children: <Widget>[
          widget.child,
          if (_highlighted && widget.enabled)
            Positioned.fill(
              child: CustomPaint(
                key: focusRingKey,
                painter: _FocusRingPainter(
                  surface: widget.surface,
                  borderRadius: widget.borderRadius,
                  outset: widget.reach,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FocusRingPainter extends CustomPainter {
  const _FocusRingPainter({
    required this.surface,
    required this.borderRadius,
    required this.outset,
  });

  final FocusRingSurface surface;
  final BorderRadius borderRadius;
  final double outset;

  @override
  void paint(Canvas canvas, Size size) {
    Border.all(color: surface.color, width: surface.width).paint(
      canvas,
      (Offset.zero & size).inflate(outset),
      borderRadius: borderRadius == BorderRadius.zero
          ? null
          : borderRadius + BorderRadius.all(Radius.circular(outset)),
    );
  }

  @override
  bool hitTest(Offset position) => false;

  @override
  bool shouldRepaint(_FocusRingPainter oldDelegate) =>
      oldDelegate.surface != surface ||
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.outset != outset;
}
