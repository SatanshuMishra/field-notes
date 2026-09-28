import 'package:flutter/widgets.dart';

enum CaptureGlyph { pencil, mic, video }

class CaptureIcon extends StatelessWidget {
  const CaptureIcon({
    super.key,
    required this.glyph,
    required this.color,
    this.size = 17,
  });

  final CaptureGlyph glyph;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: CaptureIconPainter(glyph: glyph, color: color),
        size: Size.square(size),
      ),
    );
  }
}

class CaptureIconPainter extends CustomPainter {
  const CaptureIconPainter({required this.glyph, required this.color});

  final CaptureGlyph glyph;
  final Color color;

  static const double viewBox = 24;
  static const double strokeWidth = 2;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.shortestSide / viewBox);
    canvas.drawPath(_path(), _stroke());
    canvas.restore();
  }

  Path _path() {
    switch (glyph) {
      case CaptureGlyph.pencil:
        return _pencil();
      case CaptureGlyph.mic:
        return _mic();
      case CaptureGlyph.video:
        return _video();
    }
  }

  Paint _stroke() => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  Path _pencil() => Path()
    ..moveTo(18, 5)
    ..lineTo(5, 20)
    ..lineTo(20, 9)
    ..moveTo(18, 5)
    ..lineTo(20, 9);

  Path _mic() => Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(9, 3, 6, 12),
        const Radius.circular(3),
      ),
    )
    ..moveTo(6, 11)
    ..relativeArcToPoint(
      const Offset(12, 0),
      radius: const Radius.circular(6),
      largeArc: false,
      clockwise: false,
    )
    ..moveTo(12, 17)
    ..relativeLineTo(0, 4);

  Path _video() => Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(3, 6, 13, 12),
        const Radius.circular(2),
      ),
    )
    ..moveTo(16, 10)
    ..relativeLineTo(5, -3)
    ..relativeLineTo(0, 10)
    ..relativeLineTo(-5, -3);

  @override
  bool shouldRepaint(covariant CaptureIconPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}
