import 'package:field_notes/design/tokens/tokens.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

const ValueKey<String> focusRingKey = ValueKey<String>('focus-ring');

enum FocusRingSurface {
  light(width: 3),
  dark(width: 2);

  const FocusRingSurface({required this.width});

  final double width;

  Color get color => colorIn(FieldNotesColors.light);

  Color colorIn(FieldNotesColors colors) => switch (this) {
    FocusRingSurface.light => colors.ink,
    FocusRingSurface.dark => Palette.focusRingOnDark,
  };
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
    this.paintsRing = true,
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
  final bool paintsRing;

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
      mouseCursor: widget.enabled && widget.onPressed != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      onShowFocusHighlight: _handleShowFocusHighlight,
      child: _FocusRingScope(
        highlighted: _highlighted && widget.enabled,
        surface: widget.surface,
        borderRadius: widget.borderRadius,
        outset: widget.reach,
        child: widget.paintsRing
            ? FocusRingFace(child: widget.child)
            : widget.child,
      ),
    );
  }
}

class _FocusRingScope extends InheritedWidget {
  const _FocusRingScope({
    required this.highlighted,
    required this.surface,
    required this.borderRadius,
    required this.outset,
    required super.child,
  });

  final bool highlighted;
  final FocusRingSurface surface;
  final BorderRadius borderRadius;
  final double outset;

  @override
  bool updateShouldNotify(_FocusRingScope oldWidget) =>
      oldWidget.highlighted != highlighted ||
      oldWidget.surface != surface ||
      oldWidget.borderRadius != borderRadius ||
      oldWidget.outset != outset;
}

class FocusRingFace extends StatelessWidget {
  const FocusRingFace({super.key, required this.child, this.borderRadius});

  final Widget child;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final _FocusRingScope? scope = context
        .dependOnInheritedWidgetOfExactType<_FocusRingScope>();
    if (scope == null) {
      return child;
    }
    return Stack(
      alignment: Alignment.topLeft,
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: <Widget>[
        child,
        if (scope.highlighted)
          Positioned.fill(
            child: CustomPaint(
              key: focusRingKey,
              painter: _FocusRingPainter(
                color: scope.surface.colorIn(context.colors),
                width: scope.surface.width,
                borderRadius: borderRadius ?? scope.borderRadius,
                outset: scope.outset,
              ),
            ),
          ),
      ],
    );
  }
}

class _FocusRingPainter extends CustomPainter {
  const _FocusRingPainter({
    required this.color,
    required this.width,
    required this.borderRadius,
    required this.outset,
  });

  final Color color;
  final double width;
  final BorderRadius borderRadius;
  final double outset;

  @override
  void paint(Canvas canvas, Size size) {
    Border.all(color: color, width: width).paint(
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
      oldDelegate.color != color ||
      oldDelegate.width != width ||
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.outset != outset;
}
