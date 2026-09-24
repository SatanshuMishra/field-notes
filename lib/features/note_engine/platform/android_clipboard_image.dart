import 'package:flutter/services.dart';

import 'package:field_notes/features/note_engine/platform/image_pasteboard.dart';

const String androidClipboardImageChannelName = 'field_notes/clipboard_image';

final class AndroidClipboardImage {
  const AndroidClipboardImage({
    this._channel = const MethodChannel(androidClipboardImageChannelName),
  });

  final MethodChannel _channel;

  Future<bool> hasImage() async {
    try {
      final bool? answer = await _channel.invokeMethod<bool>('hasImage');
      return answer ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<PastedImage?> readImage() async {
    final Map<Object?, Object?>? answer;
    try {
      answer = await _channel.invokeMethod<Map<Object?, Object?>>('image');
    } on MissingPluginException {
      return null;
    }
    final Object? bytes = answer?['bytes'];
    final Object? mime = answer?['mime'];
    if (bytes is! Uint8List || mime is! String) {
      return null;
    }
    return PastedImage(bytes: bytes, mime: mime);
  }
}
