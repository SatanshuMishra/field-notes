import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/interaction/hover_style.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

const ValueKey<String> pressableHoverFillKey = ValueKey<String>(
  'pressable-hover-fill',
);

const BorderRadius _circleRingRadius = BorderRadius.all(Radius.circular(9999));

typedef PressableBuilder = Widget Function(BuildContext context, bool hovered);

class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    this.child,
    this.builder,
    this.onPressed,
    this.onPressedAt,
    required this.label,
    this.borderRadius = BorderRadius.zero,
    this.surface = FocusRingSurface.light,
    this.shape = HoverShape.rounded,
    this.paintsHover = true,
    this.tooltip,
    this.value,
    this.hint,
    this.selected,
    this.toggled,
    this.checked,
    this.inMutuallyExclusiveGroup,
    this.excludeSemantics = true,
    this.focusNode,
    this.autofocus = false,
    this.placement = FocusRingPlacement.outside,
    this.behavior = HitTestBehavior.opaque,
    this.ringsFace = false,
    this.includeFocusSemantics = true,
  }) : assert(
         (child == null) != (builder == null),
         'Give exactly one of child and builder.',
       );

  final Widget? child;
  final PressableBuilder? builder;
  final VoidCallback? onPressed;
  final void Function(Offset localPosition)? onPressedAt;
  final String label;
  final BorderRadius borderRadius;
  final FocusRingSurface surface;
  final HoverShape shape;
  final bool paintsHover;
  final String? tooltip;
  final String? value;
  final String? hint;
  final bool? selected;
  final bool? toggled;
  final bool? checked;
  final bool? inMutuallyExclusiveGroup;
  final bool excludeSemantics;
  final FocusNode? focusNode;
  final bool autofocus;
  final FocusRingPlacement placement;
  final HitTestBehavior behavior;
  final bool ringsFace;
  final bool includeFocusSemantics;

  bool get enabled => onPressed != null || onPressedAt != null;

  bool get readsAsButton => toggled == null && checked == null;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _hovered = false;

  void _hover(bool hovered) {
    if (hovered != _hovered) {
      setState(() => _hovered = hovered);
    }
  }

  void _pressAt(Offset localPosition) {
    widget.onPressed?.call();
    widget.onPressedAt?.call(localPosition);
  }

  void _pressAtCentre() {
    final Size size = context.size ?? Size.zero;
    _pressAt(size.center(Offset.zero));
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.enabled;
    final bool hovered = enabled && _hovered;
    final PressableBuilder? builder = widget.builder;
    final Widget content = builder == null
        ? widget.child!
        : builder(context, hovered);
    final Widget face = DecoratedBox(
      key: pressableHoverFillKey,
      decoration: HoverStyle.decoration(
        color: widget.paintsHover && hovered
            ? HoverStyle.of(context, widget.surface, widget.shape)
            : null,
        shape: widget.shape,
        borderRadius: widget.borderRadius,
      ),
      child: ExcludeSemantics(
        excluding: widget.excludeSemantics,
        child: content,
      ),
    );
    final Widget pressable = MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (PointerEnterEvent _) => _hover(true),
      onExit: (PointerExitEvent _) => _hover(false),
      child: GestureDetector(
        behavior: widget.behavior,
        excludeFromSemantics: true,
        onTapUp: enabled
            ? (TapUpDetails details) => _pressAt(details.localPosition)
            : null,
        child: FocusRing(
          enabled: enabled,
          onPressed: enabled ? _pressAtCentre : null,
          focusNode: widget.focusNode,
          autofocus: widget.autofocus,
          surface: widget.surface,
          borderRadius: widget.shape == HoverShape.circle
              ? _circleRingRadius
              : widget.borderRadius,
          placement: widget.placement,
          paintsRing: !widget.ringsFace,
          includeFocusSemantics: widget.includeFocusSemantics,
          child: face,
        ),
      ),
    );
    final String? tooltip = widget.tooltip;
    return Semantics(
      container: true,
      button: widget.readsAsButton,
      enabled: enabled,
      label: widget.label,
      value: widget.value,
      hint: widget.hint,
      selected: widget.selected,
      toggled: widget.toggled,
      checked: widget.checked,
      inMutuallyExclusiveGroup: widget.inMutuallyExclusiveGroup,
      onTap: enabled ? _pressAtCentre : null,
      child: tooltip == null
          ? pressable
          : Tooltip(
              message: tooltip,
              excludeFromSemantics: true,
              child: pressable,
            ),
    );
  }
}
