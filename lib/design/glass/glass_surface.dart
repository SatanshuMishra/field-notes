import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../tokens/tokens.dart';

@immutable
final class GlassColors {
  const GlassColors({
    required this.tint,
    required this.border,
    required this.highlight,
    required this.pill,
    required this.shadows,
  });

  static const GlassColors paperLight = GlassColors(
    tint: Color.fromRGBO(255, 250, 240, 0.55),
    border: Color.fromRGBO(255, 255, 255, 0.65),
    highlight: Color.fromRGBO(255, 255, 255, 0.75),
    pill: Color.fromRGBO(199, 106, 84, 0.13),
    shadows: <BoxShadow>[
      BoxShadow(
        color: Color.fromRGBO(74, 59, 46, 0.45),
        offset: Offset(0, 12),
        blurRadius: 30,
        spreadRadius: -14,
      ),
    ],
  );

  static const GlassColors paperDark = GlassColors(
    tint: Color.fromRGBO(40, 33, 26, 0.58),
    border: Color.fromRGBO(255, 245, 230, 0.16),
    highlight: Color.fromRGBO(255, 255, 255, 0.08),
    pill: Color.fromRGBO(232, 146, 122, 0.2),
    shadows: <BoxShadow>[
      BoxShadow(
        color: Color.fromRGBO(0, 0, 0, 0.6),
        offset: Offset(0, 12),
        blurRadius: 30,
        spreadRadius: -14,
      ),
    ],
  );

  static const GlassColors scene = GlassColors(
    tint: Color.fromRGBO(28, 22, 16, 0.34),
    border: Color.fromRGBO(255, 250, 240, 0.22),
    highlight: Color.fromRGBO(255, 255, 255, 0.18),
    pill: Color.fromRGBO(255, 250, 240, 0.24),
    shadows: <BoxShadow>[
      BoxShadow(
        color: Color.fromRGBO(0, 0, 0, 0.55),
        offset: Offset(0, 12),
        blurRadius: 30,
        spreadRadius: -12,
      ),
    ],
  );

  static const GlassColors toast = GlassColors(
    tint: Color.fromRGBO(40, 30, 22, 0.62),
    border: Color.fromRGBO(255, 250, 240, 0.22),
    highlight: Color.fromRGBO(255, 255, 255, 0.16),
    pill: Color.fromRGBO(255, 250, 240, 0.24),
    shadows: Shadows.toastLift,
  );

  final Color tint;
  final Color border;
  final Color highlight;
  final Color pill;
  final List<BoxShadow> shadows;

  GlassColors copyWith({
    Color? tint,
    Color? border,
    Color? highlight,
    Color? pill,
    List<BoxShadow>? shadows,
  }) {
    return GlassColors(
      tint: tint ?? this.tint,
      border: border ?? this.border,
      highlight: highlight ?? this.highlight,
      pill: pill ?? this.pill,
      shadows: shadows ?? this.shadows,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GlassColors &&
      other.tint == tint &&
      other.border == border &&
      other.highlight == highlight &&
      other.pill == pill &&
      listEquals(other.shadows, shadows);

  @override
  int get hashCode =>
      Object.hash(tint, border, highlight, pill, Object.hashAll(shadows));
}

enum GlassTone {
  paper,
  scene,
  toast;

  GlassColors colorsFor(Brightness brightness) => switch ((this, brightness)) {
    (GlassTone.paper, Brightness.light) => GlassColors.paperLight,
    (GlassTone.paper, Brightness.dark) => GlassColors.paperDark,
    (GlassTone.scene, _) => GlassColors.scene,
    (GlassTone.toast, _) => GlassColors.toast,
  };

  Color pillFor(Brightness brightness) => colorsFor(brightness).pill;
}

const double glassBlurSigma = 18;
const double glassSaturation = 1.6;
const double glassBorderWidth = 1;
const double glassHighlightWidth = 1;

const List<double> _glassSaturationMatrix = <double>[
  0.213 + 0.787 * glassSaturation,
  0.715 - 0.715 * glassSaturation,
  0.072 - 0.072 * glassSaturation,
  0,
  0,
  0.213 - 0.213 * glassSaturation,
  0.715 + 0.285 * glassSaturation,
  0.072 - 0.072 * glassSaturation,
  0,
  0,
  0.213 - 0.213 * glassSaturation,
  0.715 - 0.715 * glassSaturation,
  0.072 + 0.928 * glassSaturation,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
];

final ui.ImageFilter glassBackdropFilter = ui.ImageFilter.compose(
  outer: const ColorFilter.matrix(_glassSaturationMatrix),
  inner: ui.ImageFilter.blur(sigmaX: glassBlurSigma, sigmaY: glassBlurSigma),
);

class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.tone,
    required this.borderRadius,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.tint,
    this.border,
    this.shadows,
  });

  final GlassTone tone;
  final BorderRadius borderRadius;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? tint;
  final BoxBorder? border;
  final List<BoxShadow>? shadows;

  @override
  Widget build(BuildContext context) {
    final GlassColors colors = tone.colorsFor(Theme.of(context).brightness);
    final TextDirection direction =
        Directionality.maybeOf(context) ?? TextDirection.ltr;
    final BoxBorder edge =
        border ?? Border.all(color: colors.border, width: glassBorderWidth);

    return CustomPaint(
      foregroundPainter: GlassShadowPainter(
        shadows: shadows ?? colors.shadows,
        borderRadius: borderRadius,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: glassBackdropFilter,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tint ?? colors.tint,
              border: edge,
              borderRadius: borderRadius,
            ),
            child: CustomPaint(
              painter: GlassHighlightPainter(
                color: colors.highlight,
                borderRadius: borderRadius,
                insets: edge.dimensions.resolve(direction),
              ),
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class GlassShadowPainter extends CustomPainter {
  const GlassShadowPainter({required this.shadows, required this.borderRadius});

  final List<BoxShadow> shadows;
  final BorderRadius borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    if (shadows.isEmpty) {
      return;
    }
    final Rect bounds = Offset.zero & size;
    final RRect body = borderRadius.toRRect(bounds);
    final Rect reach = shadows.fold<Rect>(
      bounds,
      (Rect area, BoxShadow shadow) => area.expandToInclude(
        bounds
            .shift(shadow.offset)
            .inflate(shadow.spreadRadius.abs() + shadow.blurRadius * 3),
      ),
    );
    final Path outside = Path.combine(
      PathOperation.difference,
      Path()..addRect(reach),
      Path()..addRRect(body),
    );

    canvas.save();
    canvas.clipPath(outside);
    for (final BoxShadow shadow in shadows) {
      canvas.drawRRect(
        body.shift(shadow.offset).inflate(shadow.spreadRadius),
        shadow.toPaint(),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(GlassShadowPainter oldDelegate) =>
      !listEquals(oldDelegate.shadows, shadows) ||
      oldDelegate.borderRadius != borderRadius;
}

class GlassHighlightPainter extends CustomPainter {
  const GlassHighlightPainter({
    required this.color,
    required this.borderRadius,
    required this.insets,
  });

  final Color color;
  final BorderRadius borderRadius;
  final EdgeInsets insets;

  @override
  void paint(Canvas canvas, Size size) {
    final RRect outer = borderRadius.toRRect(Offset.zero & size);
    final Rect innerRect = insets.deflateRect(outer.outerRect);
    if (innerRect.isEmpty) {
      return;
    }
    final RRect inner = RRect.fromRectAndCorners(
      innerRect,
      topLeft: _inset(outer.tlRadius, insets.left, insets.top),
      topRight: _inset(outer.trRadius, insets.right, insets.top),
      bottomRight: _inset(outer.brRadius, insets.right, insets.bottom),
      bottomLeft: _inset(outer.blRadius, insets.left, insets.bottom),
    );
    final Path band = Path.combine(
      PathOperation.difference,
      Path()..addRRect(inner),
      Path()..addRRect(inner.shift(const Offset(0, glassHighlightWidth))),
    );
    canvas.drawPath(band, Paint()..color = color);
  }

  Radius _inset(Radius radius, double horizontal, double vertical) {
    return Radius.elliptical(
      math.max(0, radius.x - horizontal),
      math.max(0, radius.y - vertical),
    );
  }

  @override
  bool shouldRepaint(GlassHighlightPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.insets != insets;
}
