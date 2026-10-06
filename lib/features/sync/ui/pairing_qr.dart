import 'package:field_notes/design/tokens/tokens.dart';
import 'package:flutter/widgets.dart';

import 'flower_qr.dart';

const String pairingQrLabel = 'Code to scan with your other device';

const double _quietZone = 12;
const double _eyeRadius = 2;
const double _eyeInnerRadius = 1.2;
const double _eyePupilRadius = 1;
const double _petalOutline = 0.3;
const double _heartRing = 1;

class PairingQr extends StatefulWidget {
  const PairingQr({super.key, required this.payload, this.size = 260});

  final String payload;
  final double size;

  @override
  State<PairingQr> createState() => _PairingQrState();
}

class _PairingQrState extends State<PairingQr> {
  late FlowerQr _code = FlowerQr.encode(widget.payload);

  @override
  void didUpdateWidget(PairingQr oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.payload != widget.payload) {
      _code = FlowerQr.encode(widget.payload);
    }
  }

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors scannable = FieldNotesColors.light;
    return Semantics(
      label: pairingQrLabel,
      image: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scannable.cardBright,
          border: context.shadows.outline,
          borderRadius: Shapes.buttonBorderRadius,
        ),
        child: Padding(
          padding: const EdgeInsets.all(_quietZone),
          child: CustomPaint(
            size: Size.square(widget.size - 2 * _quietZone),
            painter: FlowerQrPainter(code: _code, colors: scannable),
          ),
        ),
      ),
    );
  }
}

class FlowerQrPainter extends CustomPainter {
  const FlowerQrPainter({required this.code, required this.colors});

  final FlowerQr code;
  final FieldNotesColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint ink = Paint()..color = colors.ink;
    final Path modules = Path();
    for (int row = 0; row < code.size; row++) {
      for (int col = 0; col < code.size; col++) {
        if (code.isDark(row, col) &&
            !code.inFinder(row, col) &&
            !code.hiddenByFlower(row, col)) {
          modules.addRect(Rect.fromLTWH(col.toDouble(), row.toDouble(), 1, 1));
        }
      }
    }
    canvas
      ..save()
      ..scale(size.shortestSide / code.size)
      ..drawPath(modules, ink);
    for (final Offset corner in code.finderCorners) {
      _paintEye(canvas, corner, ink);
    }
    if (code.blooms) {
      _paintFlower(canvas);
    }
    canvas.restore();
  }

  void _paintEye(Canvas canvas, Offset corner, Paint ink) {
    final Rect outer = corner & Size.square(qrFinderSize.toDouble());
    canvas
      ..drawDRRect(
        RRect.fromRectAndRadius(outer, const Radius.circular(_eyeRadius)),
        RRect.fromRectAndRadius(
          outer.deflate(1),
          const Radius.circular(_eyeInnerRadius),
        ),
        ink,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          outer.deflate(2),
          const Radius.circular(_eyePupilRadius),
        ),
        ink,
      );
  }

  void _paintFlower(Canvas canvas) {
    final Paint petal = Paint()..color = colors.cardWarm;
    final Paint outline = Paint()
      ..color = colors.accentInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = _petalOutline;
    for (final Offset centre in code.petalCentres) {
      canvas
        ..drawCircle(centre, flowerPetalRadius, petal)
        ..drawCircle(centre, flowerPetalRadius - _petalOutline / 2, outline);
    }
    final Paint heartInk = Paint()..color = colors.accentInkStrong;
    canvas
      ..drawCircle(code.heart, flowerHeartRadius, heartInk)
      ..drawCircle(
        code.heart,
        flowerHeartRadius - _heartRing,
        Paint()..color = colors.accentTint,
      )
      ..drawCircle(code.heart, flowerHeartRadius - 2 * _heartRing, heartInk);
  }

  @override
  bool shouldRepaint(FlowerQrPainter oldDelegate) =>
      oldDelegate.code != code || oldDelegate.colors != colors;
}
