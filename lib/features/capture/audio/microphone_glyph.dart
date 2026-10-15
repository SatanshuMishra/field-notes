import 'dart:math' as math;

import 'package:field_notes/features/capture/video/camera_glyphs.dart';
import 'package:flutter/widgets.dart';

const double _stroke = 1.8;
const double _viewBox = 24;

class MicrophoneGlyph extends StatelessWidget {
  const MicrophoneGlyph({super.key, this.color = cameraGlyphInk});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: cameraGlyphSize,
      child: CustomPaint(painter: _MicrophoneGlyphPainter(color)),
    );
  }
}

class _MicrophoneGlyphPainter extends CustomPainter {
  const _MicrophoneGlyphPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.save();
    canvas.scale(size.shortestSide / _viewBox);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(9, 2.5, 6, 11.5),
        const Radius.circular(3),
      ),
      stroke,
    );
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(12, 11), radius: 6.5),
      0,
      math.pi,
      false,
      stroke,
    );
    canvas.drawLine(const Offset(12, 17.5), const Offset(12, 21), stroke);
    canvas.drawLine(const Offset(8.5, 21), const Offset(15.5, 21), stroke);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MicrophoneGlyphPainter oldDelegate) =>
      oldDelegate.color != color;
}
