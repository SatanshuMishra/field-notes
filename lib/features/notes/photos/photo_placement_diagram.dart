import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:field_notes/design/tokens/tokens.dart';

import '../model/photo_placement.dart';
import '../render/note_photo_plan.dart';

const double photoDiagramWidth = 44;
const double photoDiagramHeight = 40;
const String photoStackedDescription = 'text sits above and below';
const String photoFloatedDescription = 'text wraps beside it';

const double _diagramGap = 10;
const double _pageInset = 3;
const double _lineThickness = 2;
const double _lineGap = 2.5;
const double _bandGap = 2;
const int _linesAround = 1;

String photoPlacementSentence(PhotoPlan plan) {
  final String label = plan.sideApplies
      ? '${plan.side.label} · ${plan.size.label}'
      : plan.size.label;
  final String layout =
      plan.isStacked ? photoStackedDescription : photoFloatedDescription;
  return '$label — on this screen, $layout';
}

class PhotoPlacementDiagram extends StatelessWidget {
  const PhotoPlacementDiagram({super.key, required this.plan});

  final PhotoPlan plan;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        ExcludeSemantics(
          child: SizedBox(
            width: photoDiagramWidth,
            height: photoDiagramHeight,
            child: CustomPaint(painter: PhotoDiagramPainter(plan: plan)),
          ),
        ),
        const SizedBox(width: _diagramGap),
        Expanded(
          child: Text(
            photoPlacementSentence(plan),
            style: TypographyTokens.captionSans.copyWith(
              color: Palette.inkSoft,
            ),
          ),
        ),
      ],
    );
  }
}

class PhotoDiagramPainter extends CustomPainter {
  const PhotoDiagramPainter({required this.plan});

  final PhotoPlan plan;

  @override
  void paint(Canvas canvas, Size size) {
    final RRect page = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(Shapes.radiusXs),
    );
    canvas.drawRRect(page, Paint()..color = Palette.cardBright);
    canvas.drawRRect(
      page,
      Paint()
        ..color = Palette.ink40
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final Rect inner = page.outerRect.deflate(_pageInset);
    final double scale = plan.measure > 0 ? inner.width / plan.measure : 0;
    if (plan.isStacked) {
      _paintStacked(canvas, inner, scale);
    } else {
      _paintFloated(canvas, inner, scale);
    }
  }

  void _paintStacked(Canvas canvas, Rect inner, double scale) {
    const double lines = _linesAround * (_lineThickness + _lineGap);
    final double room = math.max(0, inner.height - 2 * lines - 2 * _bandGap);
    final Size photo = _fit(
      Size(plan.width * scale, plan.height * scale),
      Size(inner.width, room),
    );
    double y = inner.top;
    y = _textLines(canvas, inner.left, inner.width, y, _linesAround);
    final double top = y + _bandGap + (room - photo.height) / 2;
    _photo(
      canvas,
      Rect.fromLTWH(
        inner.left + (inner.width - photo.width) / 2,
        top,
        photo.width,
        photo.height,
      ),
    );
    _textLines(
      canvas,
      inner.left,
      inner.width,
      inner.bottom - lines + _lineGap,
      _linesAround,
    );
  }

  void _paintFloated(Canvas canvas, Rect inner, double scale) {
    final Size photo = _fit(
      Size(plan.width * scale, plan.height * scale),
      inner.size,
    );
    final bool onLeft = plan.side == PhotoSide.left;
    final double photoLeft =
        onLeft ? inner.left : inner.right - photo.width;
    _photo(
      canvas,
      Rect.fromLTWH(photoLeft, inner.top, photo.width, photo.height),
    );
    final double bandWidth = inner.width - photo.width - _bandGap;
    final double bandLeft =
        onLeft ? inner.left + photo.width + _bandGap : inner.left;
    final int beside =
        (photo.height / (_lineThickness + _lineGap)).floor().clamp(1, 12);
    double y = _textLines(canvas, bandLeft, bandWidth, inner.top, beside);
    y = math.max(y, inner.top + photo.height + _bandGap);
    final int below =
        ((inner.bottom - y) / (_lineThickness + _lineGap)).floor();
    _textLines(canvas, inner.left, inner.width, y, below);
  }

  double _textLines(
    Canvas canvas,
    double left,
    double width,
    double top,
    int count,
  ) {
    final Paint ink = Paint()..color = Palette.ink25;
    double y = top;
    for (int i = 0; i < count; i++) {
      canvas.drawRect(Rect.fromLTWH(left, y, width, _lineThickness), ink);
      y += _lineThickness + _lineGap;
    }
    return y;
  }

  void _photo(Canvas canvas, Rect rect) {
    canvas.drawRect(rect, Paint()..color = Palette.coral30);
    canvas.drawRect(
      rect,
      Paint()
        ..color = Palette.coral
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  Size _fit(Size photo, Size room) {
    return Size(
      photo.width.clamp(0.0, room.width),
      photo.height.clamp(0.0, room.height),
    );
  }

  @override
  bool shouldRepaint(PhotoDiagramPainter oldDelegate) =>
      oldDelegate.plan != plan;
}
