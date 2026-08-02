@Tags(<String>['golden'])
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/widgets/widgets.dart';

import 'golden_harness.dart';

const double _flatDegrees = 0;
const double _tiltDegrees = -0.5;
const EdgeInsets _boundaryPadding = EdgeInsets.all(8);
const Widget _cardChild = SizedBox(width: 120, height: 64);

Future<void> _pumpCard(WidgetTester tester, double rotationDegrees) async {
  await tester.pumpWidget(
    goldenHarness(
      StickerCard(rotationDegrees: rotationDegrees, child: _cardChild),
      padding: _boundaryPadding,
    ),
  );
}

Future<void> _captureCard(
  WidgetTester tester,
  double rotationDegrees,
  String name,
) async {
  pinGoldenSurface(tester);

  await _pumpCard(tester, rotationDegrees);

  await expectLater(
    find.byType(RepaintBoundary),
    matchesGoldenFile('images/$name.png'),
  );
}

Future<Uint8List> _capturePixels(
  WidgetTester tester,
  double rotationDegrees,
) async {
  await _pumpCard(tester, rotationDegrees);

  final RenderRepaintBoundary boundary =
      tester.renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary));
  final ByteData? pixels = await tester.runAsync<ByteData?>(() async {
    final ui.Image image = await boundary.toImage();
    return image.toByteData(format: ui.ImageByteFormat.rawRgba);
  });
  final ByteData rgba = pixels!;
  return rgba.buffer.asUint8List(rgba.offsetInBytes, rgba.lengthInBytes);
}

void main() {
  testWidgets('the default sticker card matches its golden', (
    WidgetTester tester,
  ) async {
    await _captureCard(tester, _flatDegrees, 'sticker_card_default');
  });

  testWidgets('the rotated sticker card matches its golden', (
    WidgetTester tester,
  ) async {
    await _captureCard(tester, _tiltDegrees, 'sticker_card_rotated');
  });

  testWidgets('the rotated card capture differs from the default capture', (
    WidgetTester tester,
  ) async {
    pinGoldenSurface(tester);

    final Uint8List flat = await _capturePixels(tester, _flatDegrees);
    final Uint8List tilted = await _capturePixels(tester, _tiltDegrees);

    expect(tilted.length, flat.length);
    expect(tilted, isNot(equals(flat)));
  });
}
