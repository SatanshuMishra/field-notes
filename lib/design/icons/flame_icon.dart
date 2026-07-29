import 'package:flutter/widgets.dart';

class FlameIcon extends StatelessWidget {
  const FlameIcon({
    super.key,
    required this.color,
    this.size = 17,
  });

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: FlameIconPainter(color: color),
        size: Size.square(size),
      ),
    );
  }
}

class FlameIconPainter extends CustomPainter {
  const FlameIconPainter({required this.color});

  final Color color;

  static const double viewBox = 24;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.shortestSide / viewBox);
    canvas.drawPath(_flame(), _fill());
    canvas.restore();
  }

  Paint _fill() => Paint()
    ..color = color
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;

  Path _flame() => Path()
    ..moveTo(12, 3)
    ..relativeCubicTo(3, 4, 5, 6, 5, 9)
    ..relativeArcToPoint(
      const Offset(-10, 0),
      radius: const Radius.circular(5),
      largeArc: false,
      clockwise: true,
    )
    ..relativeCubicTo(0, -2, 1, -3, 2, -4)
    ..relativeCubicTo(0, 2, 1, 3, 2, 3)
    ..relativeCubicTo(-1, -3, 1, -5, 1, -8)
    ..close();

  @override
  bool shouldRepaint(covariant FlameIconPainter oldDelegate) =>
      oldDelegate.color != color;
}
