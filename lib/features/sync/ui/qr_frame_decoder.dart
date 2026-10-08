import 'dart:isolate';
import 'dart:typed_data';

import 'package:camera_macos/camera_macos.dart' show CameraImageData;
import 'package:field_notes/data/sync/pairing/pairing_code.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

typedef QrFrameDecode = Future<String?> Function(CameraImageData frame);

const int _bytesPerPixel = 4;

DecodeParams qrDecodeParamsFor({
  required int width,
  required int height,
  required int bytesPerRow,
}) => DecodeParams(
  imageFormat: ImageFormat.bgra,
  format: Format.qrCode,
  width: bytesPerRow ~/ _bytesPerPixel,
  height: height,
  cropWidth: width,
  cropHeight: height,
  tryHarder: true,
);

String? pairingCodeFromScan(Code code) {
  final String? text = code.text;
  if (!code.isValid || text == null) {
    return null;
  }
  return text.trim().toLowerCase().startsWith('$pairingScheme:') ? text : null;
}

Future<String?> decodeQrFrame(CameraImageData frame) {
  final Uint8List bytes = frame.bytes;
  final DecodeParams params = qrDecodeParamsFor(
    width: frame.width,
    height: frame.height,
    bytesPerRow: frame.bytesPerRow,
  );
  return Isolate.run<String?>(
    () => pairingCodeFromScan(zx.readBarcode(bytes, params)),
  );
}
