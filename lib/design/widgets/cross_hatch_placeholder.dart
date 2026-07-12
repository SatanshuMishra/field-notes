import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';

class CrossHatchPlaceholder extends StatelessWidget {
  const CrossHatchPlaceholder({
    super.key,
    this.width,
    this.height,
    this.borderRadius = Shapes.cardBorderRadius,
    this.background = Palette.cardWarm,
    this.hatchColor = Palette.placeholder,
    this.child,
  });

  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final Color background;
  final Color hatchColor;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          border: Shapes.outline,
          borderRadius: borderRadius,
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: CustomPaint(
            painter: CrossHatchPainter(color: hatchColor),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

class CrossHatchPainter extends CustomPainter {
  const CrossHatchPainter({
    required this.color,
    this.spacing = 8,
    this.strokeWidth = 1,
  });

  final Color color;
  final double spacing;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    final double diagonal = size.width + size.height;
    for (double d = 0; d <= diagonal; d += spacing) {
      canvas.drawLine(Offset(d, 0), Offset(0, d), stroke);
      canvas.drawLine(
        Offset(size.width - d, 0),
        Offset(size.width, d),
        stroke,
      );
    }
  }

  @override
  bool shouldRepaint(CrossHatchPainter oldDelegate) {
    return color != oldDelegate.color ||
        spacing != oldDelegate.spacing ||
        strokeWidth != oldDelegate.strokeWidth;
  }
}
