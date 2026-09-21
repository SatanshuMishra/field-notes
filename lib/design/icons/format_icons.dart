import 'package:flutter/widgets.dart';

enum FormatGlyph { bold, italic, heading, list, quote, link, undo }

class FormatIcon extends StatelessWidget {
  const FormatIcon({
    super.key,
    required this.glyph,
    required this.color,
    this.size = 17,
  });

  final FormatGlyph glyph;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: FormatIconPainter(glyph: glyph, color: color),
        size: Size.square(size),
      ),
    );
  }
}

class FormatIconPainter extends CustomPainter {
  const FormatIconPainter({required this.glyph, required this.color});

  final FormatGlyph glyph;
  final Color color;

  static const double viewBox = 24;
  static const double strokeWidth = 2;
  static const double dotRadius = 1.3;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.shortestSide / viewBox);
    canvas.drawPath(_path(), _stroke());
    final Path? dots = _dots();
    if (dots != null) {
      canvas.drawPath(dots, _fill());
    }
    canvas.restore();
  }

  Paint _stroke() => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  Paint _fill() => Paint()
    ..color = color
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;

  Path? _dots() {
    if (glyph != FormatGlyph.list) {
      return null;
    }
    final Path path = Path();
    for (final double y in <double>[7, 12, 17]) {
      path.addOval(
        Rect.fromCircle(center: Offset(5.5, y), radius: dotRadius),
      );
    }
    return path;
  }

  Path _path() {
    switch (glyph) {
      case FormatGlyph.bold:
        return _bold();
      case FormatGlyph.italic:
        return _italic();
      case FormatGlyph.heading:
        return _heading();
      case FormatGlyph.list:
        return _list();
      case FormatGlyph.quote:
        return _quote();
      case FormatGlyph.link:
        return _link();
      case FormatGlyph.undo:
        return _undo();
    }
  }

  Path _bold() => Path()
    ..moveTo(7.5, 5)
    ..lineTo(7.5, 19)
    ..moveTo(7.5, 5)
    ..lineTo(13, 5)
    ..arcToPoint(
      const Offset(13, 11.6),
      radius: const Radius.circular(3.3),
      clockwise: true,
    )
    ..lineTo(7.5, 11.6)
    ..moveTo(7.5, 12)
    ..lineTo(14, 12)
    ..arcToPoint(
      const Offset(14, 19),
      radius: const Radius.circular(3.5),
      clockwise: true,
    )
    ..lineTo(7.5, 19);

  Path _italic() => Path()
    ..moveTo(10, 5)
    ..lineTo(18, 5)
    ..moveTo(6, 19)
    ..lineTo(14, 19)
    ..moveTo(14.5, 5)
    ..lineTo(9.5, 19);

  Path _heading() => Path()
    ..moveTo(6.5, 5)
    ..lineTo(6.5, 19)
    ..moveTo(17.5, 5)
    ..lineTo(17.5, 19)
    ..moveTo(6.5, 12)
    ..lineTo(17.5, 12);

  Path _list() => Path()
    ..moveTo(10.5, 7)
    ..lineTo(19, 7)
    ..moveTo(10.5, 12)
    ..lineTo(19, 12)
    ..moveTo(10.5, 17)
    ..lineTo(19, 17);

  Path _quote() => Path()
    ..moveTo(5, 5.5)
    ..lineTo(5, 18.5)
    ..moveTo(10, 8)
    ..lineTo(19, 8)
    ..moveTo(10, 12)
    ..lineTo(19, 12)
    ..moveTo(10, 16)
    ..lineTo(16, 16);

  Path _link() => Path()
    ..moveTo(10, 8)
    ..lineTo(7.8, 8)
    ..arcToPoint(
      const Offset(7.8, 16),
      radius: const Radius.circular(4),
      clockwise: false,
    )
    ..lineTo(10, 16)
    ..moveTo(14, 8)
    ..lineTo(16.2, 8)
    ..arcToPoint(
      const Offset(16.2, 16),
      radius: const Radius.circular(4),
      clockwise: true,
    )
    ..lineTo(14, 16)
    ..moveTo(8.8, 12)
    ..lineTo(15.2, 12);

  Path _undo() => Path()
    ..moveTo(8, 6.5)
    ..lineTo(3.8, 10.8)
    ..lineTo(8, 15)
    ..moveTo(3.8, 10.8)
    ..lineTo(14.5, 10.8)
    ..arcToPoint(
      const Offset(14.5, 19),
      radius: const Radius.circular(4.1),
      clockwise: true,
    )
    ..lineTo(9.5, 19);

  @override
  bool shouldRepaint(covariant FormatIconPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}
