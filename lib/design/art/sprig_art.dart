import 'package:flutter/widgets.dart';

const double _sprigViewBoxWidth = 120;
const double _sprigViewBoxHeight = 150;
const double _stemStrokeWidth = 2.2;
const double _leafStrokeWidth = 1.6;

const Color _stemColor = Color(0xFF8A9A63);
const Color _leafUpper = Color(0xFF9BB078);
const Color _leafMiddle = Color(0xFF8FA66C);
const Color _leafLower = Color(0xFFA3B782);

class SprigArt extends StatelessWidget {
  const SprigArt({
    super.key,
    this.width = _sprigViewBoxWidth,
    this.height = _sprigViewBoxHeight,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: const SprigPainter(),
        size: Size(width, height),
      ),
    );
  }
}

class SprigPainter extends CustomPainter {
  const SprigPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(
      size.width / _sprigViewBoxWidth,
      size.height / _sprigViewBoxHeight,
    );

    final Paint stem = Paint()
      ..color = _stemColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stemStrokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(_stemPath(), stem);

    final Paint outline = Paint()
      ..color = _stemColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _leafStrokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    _paintLeaf(canvas, _upperLeafPath(), _leafUpper, outline);
    _paintLeaf(canvas, _middleLeafPath(), _leafMiddle, outline);
    _paintLeaf(canvas, _lowerLeafPath(), _leafLower, outline);

    canvas.restore();
  }

  void _paintLeaf(Canvas canvas, Path path, Color fill, Paint outline) {
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(path, outline);
  }

  Path _stemPath() {
    return Path()
      ..moveTo(96, 6)
      ..cubicTo(70, 34, 58, 70, 60, 146);
  }

  Path _upperLeafPath() {
    return Path()
      ..moveTo(60, 40)
      ..cubicTo(44, 34, 34, 40, 30, 54)
      ..cubicTo(48, 56, 56, 52, 60, 40)
      ..close();
  }

  Path _middleLeafPath() {
    return Path()
      ..moveTo(64, 62)
      ..cubicTo(82, 56, 92, 62, 96, 76)
      ..cubicTo(78, 78, 70, 74, 64, 62)
      ..close();
  }

  Path _lowerLeafPath() {
    return Path()
      ..moveTo(58, 88)
      ..cubicTo(42, 82, 32, 88, 28, 102)
      ..cubicTo(46, 104, 54, 100, 58, 88)
      ..close();
  }

  @override
  bool shouldRepaint(SprigPainter oldDelegate) => false;
}
