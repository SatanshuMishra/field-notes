import 'package:flutter/widgets.dart';

const double _chevronStrokeWidth = 2;
const double _chevronArm = 5;

class ChevronGlyph extends StatelessWidget {
  const ChevronGlyph({
    super.key,
    required this.pointsBack,
    required this.color,
    this.size = 14,
  });

  final bool pointsBack;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _ChevronPainter(pointsBack: pointsBack, color: color),
        ),
      ),
    );
  }
}

class _ChevronPainter extends CustomPainter {
  const _ChevronPainter({required this.pointsBack, required this.color});

  final bool pointsBack;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _chevronStrokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double reach = pointsBack ? _chevronArm / 2 : -_chevronArm / 2;
    final Path path = Path()
      ..moveTo(cx + reach, cy - _chevronArm)
      ..lineTo(cx - reach, cy)
      ..lineTo(cx + reach, cy + _chevronArm);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(_ChevronPainter oldDelegate) =>
      oldDelegate.pointsBack != pointsBack || oldDelegate.color != color;
}
