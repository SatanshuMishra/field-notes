import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';

class DashedDivider extends StatelessWidget {
  const DashedDivider({
    super.key,
    this.axis = Axis.horizontal,
    this.thickness = 1.5,
    this.color = Palette.ink,
    this.dashLength = Shapes.dashLength,
    this.dashGap = Shapes.dashGap,
  });

  final Axis axis;
  final double thickness;
  final Color color;
  final double dashLength;
  final double dashGap;

  @override
  Widget build(BuildContext context) {
    final DashedLinePainter painter = DashedLinePainter(
      axis: axis,
      thickness: thickness,
      color: color,
      dashLength: dashLength,
      dashGap: dashGap,
    );
    if (axis == Axis.horizontal) {
      return SizedBox(
        height: thickness,
        width: double.infinity,
        child: CustomPaint(painter: painter),
      );
    }
    return SizedBox(
      width: thickness,
      height: double.infinity,
      child: CustomPaint(painter: painter),
    );
  }
}

class DashedLinePainter extends CustomPainter {
  const DashedLinePainter({
    required this.axis,
    required this.thickness,
    required this.color,
    required this.dashLength,
    required this.dashGap,
  });

  final Axis axis;
  final double thickness;
  final Color color;
  final double dashLength;
  final double dashGap;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.square;
    final double extent = axis == Axis.horizontal ? size.width : size.height;
    final double step = dashLength + dashGap;
    final double cross = thickness / 2;
    double pos = 0;
    while (pos < extent) {
      final double end = pos + dashLength < extent ? pos + dashLength : extent;
      if (axis == Axis.horizontal) {
        canvas.drawLine(Offset(pos, cross), Offset(end, cross), stroke);
      } else {
        canvas.drawLine(Offset(cross, pos), Offset(cross, end), stroke);
      }
      pos += step;
    }
  }

  @override
  bool shouldRepaint(DashedLinePainter oldDelegate) {
    return axis != oldDelegate.axis ||
        thickness != oldDelegate.thickness ||
        color != oldDelegate.color ||
        dashLength != oldDelegate.dashLength ||
        dashGap != oldDelegate.dashGap;
  }
}
