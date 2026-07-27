import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';

const double _hatchTintAlpha = 0.5;
const double _photoBandWidth = 6;
const double _photoBandPitch = 12;

class CrossHatchPlaceholder extends StatelessWidget {
  const CrossHatchPlaceholder({
    super.key,
    this.width,
    this.height,
    this.borderRadius = Shapes.cardBorderRadius,
    this.background,
    this.hatchColor,
    this.child,
  });

  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final Color? background;
  final Color? hatchColor;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final Color ground = background ?? Palette.hatchMid;
    final Color? tint = hatchColor;
    final Color band = tint == null
        ? Palette.hatchLight
        : Color.alphaBlend(tint.withValues(alpha: _hatchTintAlpha), ground);

    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: ground,
          borderRadius: borderRadius,
        ),
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            border: Shapes.outline,
            borderRadius: borderRadius,
          ),
          child: ClipRRect(
            borderRadius: borderRadius,
            child: CustomPaint(
              painter: CrossHatchPainter(
                ground: ground,
                band: band,
                bandWidth: _photoBandWidth,
                bandPitch: _photoBandPitch,
              ),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class CrossHatchPainter extends CustomPainter {
  const CrossHatchPainter({
    required this.ground,
    required this.band,
    required this.bandWidth,
    required this.bandPitch,
  })  : assert(bandWidth > 0, 'bandWidth must be positive'),
        assert(bandPitch > bandWidth, 'bandPitch must exceed bandWidth');

  final Color ground;
  final Color band;
  final double bandWidth;
  final double bandPitch;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || bandPitch <= 0 || bandWidth <= 0) {
      return;
    }

    final Rect bounds = Offset.zero & size;
    canvas.drawRect(bounds, Paint()..color = ground);

    canvas.save();
    canvas.clipRect(bounds);
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(math.pi / 4);

    final double reach = size.width + size.height;
    final int steps = (reach / bandPitch).ceil();
    final Paint bandPaint = Paint()..color = band;
    for (int step = -steps; step <= steps; step++) {
      canvas.drawRect(
        Rect.fromLTWH(-reach, step * bandPitch, reach * 2, bandWidth),
        bandPaint,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(CrossHatchPainter oldDelegate) {
    return ground != oldDelegate.ground ||
        band != oldDelegate.band ||
        bandWidth != oldDelegate.bandWidth ||
        bandPitch != oldDelegate.bandPitch;
  }
}
