import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';

enum IconStickerGlyph { gear, soundOn, soundOff }

const double _buttonExtent = 30;
const double _glyphExtent = 15;

const BorderRadius _buttonRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusIconButton),
);

const List<Offset> _gearOutline = <Offset>[
  Offset(17.9, 9.6),
  Offset(21.2, 9.9),
  Offset(21.2, 14.1),
  Offset(17.9, 14.5),
  Offset(20, 17),
  Offset(17, 20),
  Offset(14.5, 17.9),
  Offset(14.1, 21.2),
  Offset(9.9, 21.2),
  Offset(9.6, 17.9),
  Offset(7, 20),
  Offset(4, 17),
  Offset(6.1, 14.5),
  Offset(2.8, 14.1),
  Offset(2.8, 9.9),
  Offset(6.1, 9.6),
  Offset(4, 7),
  Offset(7, 4),
  Offset(9.6, 6.1),
  Offset(9.9, 2.8),
  Offset(14.1, 2.8),
  Offset(14.5, 6.1),
  Offset(17, 4),
  Offset(20, 7),
];

const Offset _gearHubCentre = Offset(12, 12);
const double _gearHubRadius = 3.4;

const List<Offset> _speakerOutline = <Offset>[
  Offset(4, 9),
  Offset(4, 15),
  Offset(8, 15),
  Offset(13, 19),
  Offset(13, 5),
  Offset(8, 9),
];

class IconStickerButton extends StatelessWidget {
  const IconStickerButton({
    super.key,
    required this.glyph,
    required this.glyphColor,
    required this.background,
    required this.semanticLabel,
    required this.onPressed,
  });

  final IconStickerGlyph glyph;
  final Color glyphColor;
  final Color background;
  final String semanticLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox.square(
          dimension: _buttonExtent,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: background,
              border: Shapes.outline,
              borderRadius: _buttonRadius,
            ),
            child: Center(
              child: IconStickerGlyphIcon(glyph: glyph, color: glyphColor),
            ),
          ),
        ),
      ),
    );
  }
}

class IconStickerGlyphIcon extends StatelessWidget {
  const IconStickerGlyphIcon({
    super.key,
    required this.glyph,
    required this.color,
    this.size = _glyphExtent,
  });

  final IconStickerGlyph glyph;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: IconStickerGlyphPainter(glyph: glyph, color: color),
        size: Size.square(size),
      ),
    );
  }
}

class IconStickerGlyphPainter extends CustomPainter {
  const IconStickerGlyphPainter({required this.glyph, required this.color});

  final IconStickerGlyph glyph;
  final Color color;

  static const double viewBox = 24;
  static const double strokeWidth = 1.8;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.shortestSide / viewBox);
    canvas.drawPath(_path(), _stroke());
    canvas.restore();
  }

  Paint _stroke() => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  Path _path() {
    switch (glyph) {
      case IconStickerGlyph.gear:
        return _gear();
      case IconStickerGlyph.soundOn:
        return _soundOn();
      case IconStickerGlyph.soundOff:
        return _soundOff();
    }
  }

  Path _gear() => Path()
    ..addPolygon(_gearOutline, true)
    ..addOval(
      Rect.fromCircle(center: _gearHubCentre, radius: _gearHubRadius),
    );

  Path _soundOn() => _speaker()
    ..moveTo(16, 9)
    ..arcToPoint(
      const Offset(16, 15),
      radius: const Radius.circular(4),
      clockwise: true,
    );

  Path _soundOff() => _speaker()
    ..moveTo(17, 9)
    ..lineTo(21, 15)
    ..moveTo(21, 9)
    ..lineTo(17, 15);

  Path _speaker() => Path()..addPolygon(_speakerOutline, true);

  @override
  bool shouldRepaint(covariant IconStickerGlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}
