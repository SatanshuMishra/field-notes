import 'package:field_notes/design/tokens/tokens.dart';
import 'package:flutter/widgets.dart';

class PairingQrPlaceholder extends StatelessWidget {
  const PairingQrPlaceholder({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Device pairing code',
      image: true,
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Palette.cardBright,
            border: Shapes.outline,
            borderRadius: Shapes.buttonBorderRadius,
          ),
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: CustomPaint(painter: PairingQrPainter()),
          ),
        ),
      ),
    );
  }
}

class PairingQrPainter extends CustomPainter {
  const PairingQrPainter({
    this.moduleColor = Palette.ink,
    this.modules = 9,
  });

  final Color moduleColor;
  final int modules;

  @override
  void paint(Canvas canvas, Size size) {
    final double cell = size.width / modules;
    final Paint fill = Paint()..color = moduleColor;
    for (int row = 0; row < modules; row++) {
      for (int col = 0; col < modules; col++) {
        if (!_isModuleFilled(row, col)) {
          continue;
        }
        canvas.drawRect(
          Rect.fromLTWH(col * cell, row * cell, cell, cell),
          fill,
        );
      }
    }
    _paintFinder(canvas, cell, 0, 0);
    _paintFinder(canvas, cell, 0, modules - 3);
    _paintFinder(canvas, cell, modules - 3, 0);
  }

  bool _isModuleFilled(int row, int col) {
    if (_isInFinder(row, col)) {
      return false;
    }
    return (row * 7 + col * 5 + row * col) % 3 == 0;
  }

  bool _isInFinder(int row, int col) {
    final bool topBand = row < 3;
    final bool bottomBand = row >= modules - 3;
    final bool leftBand = col < 3;
    final bool rightBand = col >= modules - 3;
    return (topBand && leftBand) ||
        (topBand && rightBand) ||
        (bottomBand && leftBand);
  }

  void _paintFinder(Canvas canvas, double cell, int row, int col) {
    final Paint stroke = Paint()
      ..color = moduleColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 0.5;
    canvas.drawRect(
      Rect.fromLTWH(
        col * cell + cell * 0.25,
        row * cell + cell * 0.25,
        cell * 2.5,
        cell * 2.5,
      ),
      stroke,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        col * cell + cell,
        row * cell + cell,
        cell,
        cell,
      ),
      Paint()..color = moduleColor,
    );
  }

  @override
  bool shouldRepaint(PairingQrPainter oldDelegate) {
    return moduleColor != oldDelegate.moduleColor ||
        modules != oldDelegate.modules;
  }
}
