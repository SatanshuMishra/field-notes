import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'photo_picker.dart';

const String undecodablePhotoMessage =
    "Couldn't read that photo. This device can't decode its format, so it was "
    'not added.';

class PhotoIntrinsics {
  const PhotoIntrinsics({required this.width, required this.height});

  final int width;
  final int height;

  int get longEdge => width > height ? width : height;

  @override
  bool operator ==(Object other) =>
      other is PhotoIntrinsics && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() => 'PhotoIntrinsics(${width}x$height)';
}

Future<PhotoIntrinsics> readPhotoIntrinsics(Uint8List bytes) =>
    _describe(() => ui.ImmutableBuffer.fromUint8List(bytes));

Future<PhotoIntrinsics> readPhotoIntrinsicsOfFile(File file) =>
    _describe(() => ui.ImmutableBuffer.fromFilePath(file.path));

Future<PhotoIntrinsics> _describe(
  Future<ui.ImmutableBuffer> Function() open,
) async {
  final ui.ImmutableBuffer buffer;
  try {
    buffer = await open();
  } catch (error) {
    throw PhotoPickException(undecodablePhotoMessage, cause: error);
  }

  ui.ImageDescriptor? descriptor;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    final PhotoIntrinsics intrinsics = PhotoIntrinsics(
      width: descriptor.width,
      height: descriptor.height,
    );
    if (intrinsics.width <= 0 || intrinsics.height <= 0) {
      throw const PhotoPickException(undecodablePhotoMessage);
    }
    return intrinsics;
  } on PhotoPickException {
    rethrow;
  } catch (error) {
    throw PhotoPickException(undecodablePhotoMessage, cause: error);
  } finally {
    descriptor?.dispose();
    buffer.dispose();
  }
}
