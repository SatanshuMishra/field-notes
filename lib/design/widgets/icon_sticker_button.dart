import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';

enum IconStickerGlyph { gear, soundOn, soundOff, edit, trash, close, check, pause }

const double _pauseBarWidth = 4.5;
const double _pauseBarHeight = 16;
const double _pauseBarGap = 3.5;
const Radius _pauseBarRadius = Radius.circular(1.2);

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

const List<Offset> _editNib = <Offset>[
  Offset(4, 17),
  Offset(12, 6),
  Offset(20, 17),
];

const Radius _trashCorner = Radius.circular(1);

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

  bool get _isFilled => glyph == IconStickerGlyph.pause;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.shortestSide / viewBox);
    canvas.drawPath(_path(), _isFilled ? _fill() : _stroke());
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

  Path _path() {
    switch (glyph) {
      case IconStickerGlyph.gear:
        return _gear();
      case IconStickerGlyph.soundOn:
        return _soundOn();
      case IconStickerGlyph.soundOff:
        return _soundOff();
      case IconStickerGlyph.edit:
        return _edit();
      case IconStickerGlyph.trash:
        return _trash();
      case IconStickerGlyph.close:
        return _close();
      case IconStickerGlyph.check:
        return _check();
      case IconStickerGlyph.pause:
        return _pause();
    }
  }

  Path _close() => Path()
    ..moveTo(6, 6)
    ..lineTo(18, 18)
    ..moveTo(18, 6)
    ..lineTo(6, 18);

  Path _check() => Path()
    ..moveTo(5, 12.5)
    ..lineTo(10, 17.5)
    ..lineTo(19, 7);

  Path _pause() {
    final double centre = viewBox / 2;
    final double top = centre - _pauseBarHeight / 2;
    return Path()
      ..addRRect(
        RRect.fromLTRBR(
          centre - _pauseBarGap / 2 - _pauseBarWidth,
          top,
          centre - _pauseBarGap / 2,
          top + _pauseBarHeight,
          _pauseBarRadius,
        ),
      )
      ..addRRect(
        RRect.fromLTRBR(
          centre + _pauseBarGap / 2,
          top,
          centre + _pauseBarGap / 2 + _pauseBarWidth,
          top + _pauseBarHeight,
          _pauseBarRadius,
        ),
      );
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

  Path _edit() => Path()
    ..addPolygon(_editNib, false)
    ..moveTo(6, 20)
    ..lineTo(18, 20);

  Path _trash() => Path()
    ..moveTo(4, 7)
    ..lineTo(20, 7)
    ..moveTo(9, 7)
    ..lineTo(9, 5)
    ..arcToPoint(const Offset(10, 4), radius: _trashCorner)
    ..lineTo(14, 4)
    ..arcToPoint(const Offset(15, 5), radius: _trashCorner)
    ..lineTo(15, 7)
    ..moveTo(6, 7)
    ..lineTo(7, 20)
    ..arcToPoint(const Offset(8, 21), radius: _trashCorner, clockwise: false)
    ..lineTo(16, 21)
    ..arcToPoint(const Offset(17, 20), radius: _trashCorner, clockwise: false)
    ..lineTo(18, 7);

  @override
  bool shouldRepaint(covariant IconStickerGlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}
