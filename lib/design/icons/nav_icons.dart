import 'package:flutter/widgets.dart';

enum NavGlyph { home, calendar, garden, search }

class NavIcon extends StatelessWidget {
  const NavIcon({
    super.key,
    required this.glyph,
    required this.color,
    this.size = 18,
  });

  final NavGlyph glyph;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: NavIconPainter(glyph: glyph, color: color),
        size: Size.square(size),
      ),
    );
  }
}

class NavIconPainter extends CustomPainter {
  const NavIconPainter({required this.glyph, required this.color});

  final NavGlyph glyph;
  final Color color;

  static const double viewBox = 24;
  static const double strokeWidth = 2;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.shortestSide / viewBox);
    switch (glyph) {
      case NavGlyph.home:
        canvas.drawPath(_home(), _fill());
      case NavGlyph.calendar:
        canvas.drawPath(_calendar(), _stroke());
      case NavGlyph.garden:
        canvas.drawPath(_garden(), _stroke());
      case NavGlyph.search:
        canvas.drawPath(_search(), _stroke());
    }
    canvas.restore();
  }

  Paint _fill() => Paint()
    ..color = color
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;

  Paint _stroke() => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  Path _home() => Path()
    ..moveTo(4, 11)
    ..relativeLineTo(8, -7)
    ..relativeLineTo(8, 7)
    ..relativeLineTo(0, 8)
    ..relativeArcToPoint(
      const Offset(-1, 1),
      radius: const Radius.circular(1),
      clockwise: true,
    )
    ..relativeLineTo(-4, 0)
    ..relativeLineTo(0, -6)
    ..relativeLineTo(-6, 0)
    ..relativeLineTo(0, 6)
    ..lineTo(5, 20)
    ..relativeArcToPoint(
      const Offset(-1, -1),
      radius: const Radius.circular(1),
      clockwise: true,
    )
    ..close();

  Path _calendar() => Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(4, 5, 16, 16),
        const Radius.circular(2),
      ),
    )
    ..moveTo(4, 9)
    ..lineTo(20, 9)
    ..moveTo(9, 3)
    ..lineTo(9, 7)
    ..moveTo(15, 3)
    ..lineTo(15, 7);

  Path _garden() => Path()
    ..addOval(Rect.fromCircle(center: const Offset(12, 9), radius: 3))
    ..addOval(Rect.fromCircle(center: const Offset(8, 13), radius: 3))
    ..addOval(Rect.fromCircle(center: const Offset(16, 13), radius: 3))
    ..moveTo(12, 12)
    ..lineTo(12, 21);

  Path _search() => Path()
    ..addOval(Rect.fromCircle(center: const Offset(11, 11), radius: 7))
    ..moveTo(21, 21)
    ..lineTo(17, 17);

  @override
  bool shouldRepaint(covariant NavIconPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}
