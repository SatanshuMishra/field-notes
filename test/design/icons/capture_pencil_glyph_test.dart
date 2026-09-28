import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:field_notes/design/icons/capture_icons.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the pencil glyph is not mirror-symmetric', () async {
    const int size = 48;
    const CaptureIconPainter painter = CaptureIconPainter(
      glyph: CaptureGlyph.pencil,
      color: Color(0xFF000000),
    );

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);
    painter.paint(canvas, Size(size.toDouble(), size.toDouble()));
    final ui.Image image = await recorder.endRecording().toImage(size, size);
    final ByteData? bytes = await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    image.dispose();
    final ByteData rgba = bytes!;

    bool isPainted(int x, int y) {
      final int offset = ((y * size) + x) * 4;
      return rgba.getUint8(offset + 3) > 0;
    }

    int paintedCount = 0;
    int differingCount = 0;
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        if (!isPainted(x, y)) {
          continue;
        }
        paintedCount++;
        if (!isPainted(size - 1 - x, y)) {
          differingCount++;
        }
      }
    }

    expect(paintedCount, greaterThan(0));
    expect(differingCount / paintedCount, greaterThanOrEqualTo(0.1));
  });
}
