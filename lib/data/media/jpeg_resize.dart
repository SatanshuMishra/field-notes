import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;

class JpegResizeException implements Exception {
  const JpegResizeException({this.cause});

  final Object? cause;

  @override
  String toString() => 'JpegResizeException(cause: $cause)';
}

class ResizedJpeg {
  const ResizedJpeg({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;
}

class _JpegEncodeRequest {
  const _JpegEncodeRequest({
    required this.rgba,
    required this.width,
    required this.height,
    required this.quality,
  });

  final TransferableTypedData rgba;
  final int width;
  final int height;
  final int quality;
}

Uint8List _encodeJpeg(_JpegEncodeRequest request) {
  final Uint8List rgba = request.rgba.materialize().asUint8List();
  final img.Image image = img.Image.fromBytes(
    width: request.width,
    height: request.height,
    bytes: rgba.buffer,
    bytesOffset: rgba.offsetInBytes,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  return img.encodeJpg(image, quality: request.quality);
}

Future<ResizedJpeg> resizeToJpeg({
  required Uint8List bytes,
  required int sourceWidth,
  required int sourceHeight,
  required int longEdge,
  required int quality,
}) async {
  final int sourceLongEdge = math.max(sourceWidth, sourceHeight);
  final double scale = sourceLongEdge > longEdge
      ? longEdge / sourceLongEdge
      : 1;
  final int targetWidth = math.max(1, (sourceWidth * scale).round());
  final int targetHeight = math.max(1, (sourceHeight * scale).round());

  ui.Codec? codec;
  ui.FrameInfo? frame;
  try {
    codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: targetWidth,
      targetHeight: targetHeight,
    );
    frame = await codec.getNextFrame();
    final int width = frame.image.width;
    final int height = frame.image.height;
    final ByteData? raw = await frame.image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    if (raw == null) {
      throw const JpegResizeException();
    }
    final TransferableTypedData rgba = TransferableTypedData.fromList(
      <Uint8List>[raw.buffer.asUint8List(raw.offsetInBytes, raw.lengthInBytes)],
    );
    final Uint8List encoded = await Isolate.run(
      () => _encodeJpeg(
        _JpegEncodeRequest(
          rgba: rgba,
          width: width,
          height: height,
          quality: quality,
        ),
      ),
    );
    return ResizedJpeg(bytes: encoded, width: width, height: height);
  } on JpegResizeException {
    rethrow;
  } catch (error) {
    throw JpegResizeException(cause: error);
  } finally {
    frame?.image.dispose();
    codec?.dispose();
  }
}
