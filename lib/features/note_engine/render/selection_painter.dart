import 'package:flutter/rendering.dart';

const double noteComposingUnderlineThickness = 1;

void paintNoteSelection(Canvas canvas, List<Rect> boxes, Color color) {
  final Paint paint = Paint()..color = color;
  for (final Rect box in boxes) {
    canvas.drawRect(box, paint);
  }
}

List<Rect> noteComposingUnderlines(List<Rect> boxes) =>
    List<Rect>.unmodifiable(<Rect>[
      for (final Rect box in boxes)
        Rect.fromLTWH(
          box.left,
          box.bottom - noteComposingUnderlineThickness,
          box.width,
          noteComposingUnderlineThickness,
        ),
    ]);

void paintNoteComposingUnderline(
  Canvas canvas,
  List<Rect> underlines,
  Color color,
) {
  final Paint paint = Paint()..color = color;
  for (final Rect underline in underlines) {
    canvas.drawRect(underline, paint);
  }
}
