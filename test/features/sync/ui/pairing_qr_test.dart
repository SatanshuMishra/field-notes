import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/sync/ui/flower_qr.dart';
import 'package:field_notes/features/sync/ui/pairing_qr.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../design/widgets/widget_harness.dart';

const String _payload =
    'fieldnotes-pair:https://sync.satanshu.tech#Q2xvdmVyLWZpZWxk';
const String _otherPayload =
    'fieldnotes-pair:https://sync.satanshu.tech#bWVhZG93LXN3ZWV0';

const double _pixelsPerModule = 8;

Future<ByteData> _paintedPixels(WidgetTester tester, FlowerQr code) async {
  final double side = code.size * _pixelsPerModule;
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder)
    ..drawColor(FieldNotesColors.light.cardBright, BlendMode.src);
  FlowerQrPainter(
    code: code,
    colors: FieldNotesColors.light,
  ).paint(canvas, Size.square(side));
  final ByteData? pixels = await tester.runAsync<ByteData?>(() async {
    final ui.Image image = await recorder.endRecording().toImage(
      side.toInt(),
      side.toInt(),
    );
    return image.toByteData();
  });
  return pixels!;
}

bool _darkAt(ByteData pixels, int width, int row, int col) {
  final int x = (col * _pixelsPerModule + _pixelsPerModule / 2).floor();
  final int y = (row * _pixelsPerModule + _pixelsPerModule / 2).floor();
  final int offset = (y * width + x) * 4;
  final double luminance =
      0.299 * pixels.getUint8(offset) +
      0.587 * pixels.getUint8(offset + 1) +
      0.114 * pixels.getUint8(offset + 2);
  return luminance < 128;
}

bool _readByScanners(FlowerQr code, int row, int col) {
  if (code.inFinder(row, col)) {
    final int localRow = row < qrFinderSize ? row : row - (code.size - 7);
    final int localCol = col < qrFinderSize ? col : col - (code.size - 7);
    return localRow == 3 || localCol == 3;
  }
  final int middle = code.size ~/ 2;
  final bool heart = (row - middle).abs() <= 2 && (col - middle).abs() <= 2;
  return heart || !code.hiddenByFlower(row, col);
}

FlowerQrPainter _painter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.descendant(
                of: find.byType(PairingQr),
                matching: find.byType(CustomPaint),
              ),
            )
            .painter!
        as FlowerQrPainter;

void main() {
  testWidgets('the pairing code is a labelled flower code', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(stickerHarness(const PairingQr(payload: _payload)));

    expect(find.bySemanticsLabel(pairingQrLabel), findsOneWidget);
    expect(_painter(tester).code.payload, _payload);
    expect(_painter(tester).code.blooms, isTrue);
    expect(tester.getSize(find.byType(PairingQr)), const Size.square(260));

    semantics.dispose();
  });

  testWidgets('every module a scanner reads is painted as encoded', (
    WidgetTester tester,
  ) async {
    for (final String payload in <String>[
      _payload,
      'fieldnotes-pair:https://${'relay' * 14}.example.org#Q2xvdmVyLWZpZWxk',
    ]) {
      final FlowerQr code = FlowerQr.encode(payload);
      final ByteData pixels = await _paintedPixels(tester, code);
      final int width = (code.size * _pixelsPerModule).toInt();
      for (int row = 0; row < code.size; row++) {
        for (int col = 0; col < code.size; col++) {
          if (_readByScanners(code, row, col)) {
            expect(
              _darkAt(pixels, width, row, col),
              code.isDark(row, col),
              reason: 'version ${code.version} at ($row, $col)',
            );
          }
        }
      }
    }
  });

  testWidgets('the code is encoded again only when the payload changes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(stickerHarness(const PairingQr(payload: _payload)));
    final FlowerQr first = _painter(tester).code;

    await tester.pumpWidget(stickerHarness(const PairingQr(payload: _payload)));
    expect(_painter(tester).code, same(first));

    await tester.pumpWidget(
      stickerHarness(const PairingQr(payload: _otherPayload)),
    );
    expect(_painter(tester).code.payload, _otherPayload);
  });
}
