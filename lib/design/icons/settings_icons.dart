import 'package:flutter/widgets.dart';

enum SettingsGlyph { book, flip, bell, archive, info, download, microphone }

class SettingsIcon extends StatelessWidget {
  const SettingsIcon(
    this.glyph, {
    super.key,
    required this.size,
    required this.color,
    this.strokeWidth = SettingsIconPainter.defaultStrokeWidth,
  });

  final SettingsGlyph glyph;
  final double size;
  final Color color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: SettingsIconPainter(
            glyph: glyph,
            color: color,
            strokeWidth: strokeWidth,
          ),
          size: Size.square(size),
        ),
      ),
    );
  }
}

class SettingsIconPainter extends CustomPainter {
  const SettingsIconPainter({
    required this.glyph,
    required this.color,
    this.strokeWidth = defaultStrokeWidth,
  });

  final SettingsGlyph glyph;
  final Color color;
  final double strokeWidth;

  static const double viewBox = 24;
  static const double defaultStrokeWidth = 1.8;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.shortestSide / viewBox);
    canvas.drawPath(_path(), _stroke());
    canvas.restore();
  }

  Path _path() => switch (glyph) {
    SettingsGlyph.book => _book(),
    SettingsGlyph.flip => _flip(),
    SettingsGlyph.bell => _bell(),
    SettingsGlyph.archive => _archive(),
    SettingsGlyph.info => _info(),
    SettingsGlyph.download => _download(),
    SettingsGlyph.microphone => _microphone(),
  };

  Paint _stroke() => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  Path _book() => Path()
    ..moveTo(5, 4.5)
    ..lineTo(15, 4.5)
    ..relativeArcToPoint(
      const Offset(3, 3),
      radius: const Radius.circular(3),
      clockwise: true,
    )
    ..lineTo(18, 20)
    ..lineTo(8, 20)
    ..relativeArcToPoint(
      const Offset(-3, -3),
      radius: const Radius.circular(3),
      clockwise: true,
    )
    ..close()
    ..moveTo(5, 17)
    ..relativeArcToPoint(
      const Offset(3, -3),
      radius: const Radius.circular(3),
      clockwise: true,
    )
    ..lineTo(18, 14)
    ..moveTo(9, 8)
    ..lineTo(14, 8);

  Path _flip() => Path()
    ..moveTo(3, 8)
    ..relativeArcToPoint(
      const Offset(15, -3),
      radius: const Radius.circular(9),
      clockwise: true,
    )
    ..relativeLineTo(3, 3)
    ..moveTo(21, 16)
    ..relativeArcToPoint(
      const Offset(-15, 3),
      radius: const Radius.circular(9),
      clockwise: true,
    )
    ..relativeLineTo(-3, -3)
    ..moveTo(18, 3)
    ..lineTo(18, 8)
    ..lineTo(13, 8)
    ..moveTo(6, 21)
    ..lineTo(6, 16)
    ..lineTo(11, 16);

  Path _bell() => Path()
    ..moveTo(6, 16)
    ..lineTo(6, 11)
    ..relativeArcToPoint(
      const Offset(12, 0),
      radius: const Radius.circular(6),
      clockwise: true,
    )
    ..lineTo(18, 16)
    ..relativeLineTo(1.5, 2)
    ..relativeLineTo(-15, 0)
    ..close()
    ..moveTo(10, 20.5)
    ..relativeArcToPoint(
      const Offset(4, 0),
      radius: const Radius.circular(2),
      clockwise: false,
    );

  Path _archive() => Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(3.5, 4.5, 17, 4.5),
        const Radius.circular(1.2),
      ),
    )
    ..moveTo(5, 9)
    ..lineTo(5, 18.5)
    ..relativeArcToPoint(
      const Offset(1, 1),
      radius: const Radius.circular(1),
      clockwise: false,
    )
    ..lineTo(18, 19.5)
    ..relativeArcToPoint(
      const Offset(1, -1),
      radius: const Radius.circular(1),
      clockwise: false,
    )
    ..lineTo(19, 9)
    ..moveTo(10, 13)
    ..lineTo(14, 13);

  Path _info() => Path()
    ..addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 8.5))
    ..moveTo(12, 11)
    ..lineTo(12, 16.5)
    ..moveTo(12, 7.8)
    ..lineTo(12, 7.81);

  Path _download() => Path()
    ..moveTo(12, 4)
    ..lineTo(12, 15)
    ..moveTo(7, 10)
    ..lineTo(12, 15)
    ..lineTo(17, 10)
    ..moveTo(5, 20)
    ..lineTo(19, 20);

  Path _microphone() => Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(9, 3, 6, 11),
        const Radius.circular(3),
      ),
    )
    ..moveTo(5.5, 11)
    ..relativeArcToPoint(
      const Offset(13, 0),
      radius: const Radius.circular(6.5),
      clockwise: false,
    )
    ..moveTo(12, 17.5)
    ..lineTo(12, 21)
    ..moveTo(8.5, 21)
    ..lineTo(15.5, 21);

  @override
  bool shouldRepaint(covariant SettingsIconPainter oldDelegate) =>
      oldDelegate.glyph != glyph ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}
