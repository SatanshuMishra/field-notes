import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/glass/glass.dart';
import 'package:field_notes/design/tokens/typography.dart';

const Color meadowCream = Color.fromRGBO(251, 243, 228, 1);
const Color meadowKickerInk = Color.fromRGBO(246, 201, 184, 1);
const Color meadowGold = Color.fromRGBO(242, 193, 78, 1);
const Color meadowGlassFill = Color.fromRGBO(28, 22, 16, 0.5);
const Color meadowGlassEdge = Color.fromRGBO(255, 250, 240, 0.24);
const Color meadowGlassHighlight = Color.fromRGBO(255, 255, 255, 0.14);
const Color meadowPopoverScrim = Color.fromRGBO(20, 14, 8, 0.2);
const Color meadowRowSelected = Color.fromRGBO(255, 250, 240, 0.18);
const Color meadowTextShadow = Color.fromRGBO(0, 0, 0, 0.4);
const Cubic meadowEase = Cubic(0.2, 0.8, 0.2, 1);
const Duration meadowPopoverRise = Duration(milliseconds: 200);
const double meadowPopoverBlur = 20;
const double meadowTipBlur = 16;
const double meadowPopoverInset = 12;
const double meadowPopoverLift = 56;
const double meadowPopoverMaxShare = 0.62;
const double meadowPhoneControlHeight = 48;
const double meadowPhoneDockRadius = 14;
const String meadowPopoverDismissLabel = 'Close';
const ValueKey<String> meadowPopoverScrimKey = ValueKey<String>(
  'meadow-popover-scrim',
);
const ValueKey<String> meadowPopoverKey = ValueKey<String>('meadow-popover');

const List<BoxShadow> _popoverShadows = <BoxShadow>[
  BoxShadow(
    color: Color.fromRGBO(0, 0, 0, 0.65),
    offset: Offset(0, 18),
    blurRadius: 40,
    spreadRadius: -16,
  ),
];
const double _riseDistance = 10;
const double _saturation = 1.5;

Color meadowCreamAt(double opacity) => meadowCream.withValues(alpha: opacity);

Color meadowGlassWhite(double opacity) =>
    Color.fromRGBO(255, 250, 240, opacity);

const List<double> _saturationMatrix = <double>[
  0.213 + 0.787 * _saturation,
  0.715 - 0.715 * _saturation,
  0.072 - 0.072 * _saturation,
  0,
  0,
  0.213 - 0.213 * _saturation,
  0.715 + 0.285 * _saturation,
  0.072 - 0.072 * _saturation,
  0,
  0,
  0.213 - 0.213 * _saturation,
  0.715 - 0.715 * _saturation,
  0.072 + 0.928 * _saturation,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
];

ui.ImageFilter meadowGlassFilter(double sigma) => ui.ImageFilter.compose(
  outer: const ColorFilter.matrix(_saturationMatrix),
  inner: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
);

TextStyle meadowSans(double size, {double opacity = 1, FontWeight? weight}) =>
    TextStyle(
      fontFamily: TypographyTokens.sans,
      fontSize: size,
      fontWeight: weight ?? FontWeight.w600,
      color: meadowCreamAt(opacity),
    );

class MeadowGlass extends StatelessWidget {
  const MeadowGlass({
    super.key,
    required this.borderRadius,
    required this.child,
    this.blur = meadowPopoverBlur,
    this.fill = meadowGlassFill,
    this.edge = meadowGlassEdge,
    this.padding = EdgeInsets.zero,
    this.shadows = _popoverShadows,
  });

  final BorderRadius borderRadius;
  final Widget child;
  final double blur;
  final Color fill;
  final Color edge;
  final EdgeInsetsGeometry padding;
  final List<BoxShadow> shadows;

  @override
  Widget build(BuildContext context) {
    final Border border = Border.all(color: edge, width: glassBorderWidth);
    return CustomPaint(
      foregroundPainter: GlassShadowPainter(
        shadows: shadows,
        borderRadius: borderRadius,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: meadowGlassFilter(blur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: fill,
              border: border,
              borderRadius: borderRadius,
            ),
            child: CustomPaint(
              painter: GlassHighlightPainter(
                color: meadowGlassHighlight,
                borderRadius: borderRadius,
                insets: border.dimensions as EdgeInsets,
              ),
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class MeadowChromeBlock extends StatelessWidget {
  const MeadowChromeBlock({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(behavior: HitTestBehavior.opaque, child: child);
  }
}

class MeadowGlassButton extends StatelessWidget {
  const MeadowGlassButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.child,
    this.tooltip,
    this.width,
    this.padding = EdgeInsets.zero,
    this.selected,
    this.value,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget child;
  final String? tooltip;
  final double? width;
  final EdgeInsetsGeometry padding;
  final bool? selected;
  final String? value;

  @override
  Widget build(BuildContext context) {
    const BorderRadius radius = BorderRadius.all(
      Radius.circular(meadowPhoneDockRadius),
    );
    final Widget face = SizedBox(
      width: width,
      height: meadowPhoneControlHeight,
      child: GlassSurface(
        tone: GlassTone.scene,
        borderRadius: radius,
        padding: padding,
        child: Center(widthFactor: width == null ? 1 : null, child: child),
      ),
    );
    final String? hint = tooltip;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      selected: selected,
      label: label,
      value: value,
      onTap: onPressed,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: onPressed,
          child: FocusRing(
            onPressed: onPressed,
            enabled: onPressed != null,
            surface: FocusRingSurface.dark,
            borderRadius: radius,
            child: ExcludeSemantics(
              child: hint == null
                  ? face
                  : Tooltip(
                      message: hint,
                      excludeFromSemantics: true,
                      child: face,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class MeadowGlassPopover extends StatelessWidget {
  const MeadowGlassPopover({
    super.key,
    required this.bottom,
    required this.onDismiss,
    required this.heading,
    required this.children,
    this.maxHeight,
    this.gap = 0,
  });

  final double bottom;
  final VoidCallback onDismiss;
  final String heading;
  final List<Widget> children;
  final double? maxHeight;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final Widget list = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 2, 10, 4),
          child: Semantics(
            header: true,
            child: Text(heading, style: meadowHandStyle(15)),
          ),
        ),
        for (int index = 0; index < children.length; index++) ...<Widget>[
          if (index > 0 && gap > 0) SizedBox(height: gap),
          children[index],
        ],
      ],
    );
    final double? limit = maxHeight;
    final Widget panel = MeadowChromeBlock(
      child: MeadowGlass(
        key: meadowPopoverKey,
        borderRadius: const BorderRadius.all(Radius.circular(22)),
        padding: const EdgeInsets.all(8),
        child: limit == null
            ? list
            : ConstrainedBox(
                constraints: BoxConstraints(maxHeight: limit - 16),
                child: SingleChildScrollView(child: list),
              ),
      ),
    );
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Positioned.fill(
          child: Semantics(
            button: true,
            label: meadowPopoverDismissLabel,
            onTap: onDismiss,
            excludeSemantics: true,
            child: GestureDetector(
              key: meadowPopoverScrimKey,
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onTap: onDismiss,
              child: const ColoredBox(color: meadowPopoverScrim),
            ),
          ),
        ),
        Positioned(
          left: meadowPopoverInset,
          right: meadowPopoverInset,
          bottom: bottom,
          child: MeadowRise(child: panel),
        ),
      ],
    );
  }
}

class MeadowRise extends StatelessWidget {
  const MeadowRise({
    super.key,
    required this.child,
    this.duration = meadowPopoverRise,
    this.distance = _riseDistance,
  });

  final Widget child;
  final Duration duration;
  final double distance;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return child;
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration,
      curve: meadowEase,
      builder: (BuildContext context, double progress, Widget? child) {
        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, distance * (1 - progress)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class MeadowTimeRow extends StatelessWidget {
  const MeadowTimeRow({
    super.key,
    required this.label,
    required this.sub,
    required this.selected,
    required this.onPressed,
    required this.compact,
  });

  final String label;
  final String sub;
  final bool selected;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.all(
      Radius.circular(compact ? 14 : 12),
    );
    final TextStyle name = compact
        ? const TextStyle(
            fontFamily: TypographyTokens.serif,
            fontSize: 17,
            fontWeight: FontWeight.w500,
            color: meadowCream,
          )
        : meadowSans(13);
    final TextStyle note = meadowSans(
      compact ? 12 : 11,
      opacity: 0.72,
      weight: FontWeight.w500,
    );
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: '$label, $sub',
      onTap: onPressed,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: onPressed,
          child: FocusRing(
            onPressed: onPressed,
            surface: FocusRingSurface.dark,
            placement: FocusRingPlacement.edge,
            borderRadius: radius,
            child: _HoverFill(
              selected: selected,
              radius: radius,
              child: SizedBox(
                height: compact ? meadowPhoneControlHeight : 36,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 12),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: name,
                        ),
                      ),
                      Text(sub, maxLines: 1, softWrap: false, style: note),
                    ],
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

class _HoverFill extends StatefulWidget {
  const _HoverFill({
    required this.selected,
    required this.radius,
    required this.child,
  });

  final bool selected;
  final BorderRadius radius;
  final Widget child;

  @override
  State<_HoverFill> createState() => _HoverFillState();
}

class _HoverFillState extends State<_HoverFill> {
  bool _hovered = false;

  void _hover(bool hovered) {
    if (hovered != _hovered) {
      setState(() => _hovered = hovered);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color fill = widget.selected
        ? meadowRowSelected
        : _hovered
        ? meadowGlassWhite(0.1)
        : meadowGlassWhite(0);
    return MouseRegion(
      onEnter: (PointerEnterEvent event) => _hover(true),
      onExit: (PointerExitEvent event) => _hover(false),
      child: DecoratedBox(
        decoration: BoxDecoration(color: fill, borderRadius: widget.radius),
        child: ExcludeSemantics(child: widget.child),
      ),
    );
  }
}

TextStyle meadowHandStyle(double size) => TextStyle(
  fontFamily: TypographyTokens.accent,
  fontSize: size,
  fontWeight: FontWeight.w600,
  color: meadowKickerInk,
);
