import 'dart:async';

import 'package:flutter/rendering.dart';

const double noteCaretWidth = 2;

const Duration noteCaretBlinkHalfPeriod = Duration(milliseconds: 500);

Rect noteCaretRect({
  required Rect caret,
  required Rect lineBox,
  required double devicePixelRatio,
}) {
  double snap(double value) =>
      (value * devicePixelRatio).roundToDouble() / devicePixelRatio;
  final double left = snap(caret.left);
  return Rect.fromLTRB(
    left,
    snap(lineBox.top),
    left + noteCaretWidth,
    snap(lineBox.bottom),
  );
}

class NoteCaretBlink {
  NoteCaretBlink({required this._onChanged});

  final VoidCallback _onChanged;
  Timer? _timer;
  bool _visible = false;

  bool get visible => _visible;

  bool get isRunning => _timer?.isActive ?? false;

  void start() {
    _timer?.cancel();
    _visible = true;
    _onChanged();
    _timer = Timer.periodic(noteCaretBlinkHalfPeriod, (Timer timer) {
      _visible = !_visible;
      _onChanged();
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _visible = false;
  }
}

void paintNoteCaret(Canvas canvas, Rect rect, Color color) {
  canvas.drawRect(rect, Paint()..color = color);
}
