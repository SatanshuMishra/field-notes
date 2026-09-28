import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const String imagePasteboardChannelName = 'field_notes/pasteboard';

enum PasteboardImageType { png, tiff, jpeg, heic }

@immutable
final class PasteboardContents {
  const PasteboardContents({
    this.filePaths = const <String>[],
    this.imageTypes = const <PasteboardImageType>{},
    this.hasText = false,
  });

  final List<String> filePaths;
  final Set<PasteboardImageType> imageTypes;
  final bool hasText;

  bool get hasImageData => imageTypes.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is PasteboardContents &&
      listEquals(other.filePaths, filePaths) &&
      setEquals(other.imageTypes, imageTypes) &&
      other.hasText == hasText;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(filePaths),
    Object.hashAllUnordered(imageTypes),
    hasText,
  );
}

@immutable
final class PastedImage {
  const PastedImage({required this.bytes, required this.mime});

  final Uint8List bytes;
  final String mime;

  @override
  bool operator ==(Object other) =>
      other is PastedImage &&
      other.mime == mime &&
      listEquals(other.bytes, bytes);

  @override
  int get hashCode => Object.hash(Object.hashAll(bytes), mime);
}

final class ImagePasteboard {
  const ImagePasteboard({
    this._channel = const MethodChannel(imagePasteboardChannelName),
  });

  final MethodChannel _channel;

  Future<PasteboardContents> readContents() async {
    final Map<Object?, Object?>? answer = await _invoke('contents');
    if (answer == null) {
      return const PasteboardContents();
    }
    final Object? paths = answer['paths'];
    final Object? types = answer['imageTypes'];
    final Object? hasText = answer['hasText'];
    return PasteboardContents(
      filePaths: paths is List<Object?>
          ? List<String>.unmodifiable(paths.whereType<String>())
          : const <String>[],
      imageTypes: types is List<Object?>
          ? Set<PasteboardImageType>.unmodifiable(<PasteboardImageType>{
              for (final Object? name in types) ?_imageTypeNamed(name),
            })
          : const <PasteboardImageType>{},
      hasText: hasText is bool && hasText,
    );
  }

  Future<PastedImage?> readImage() async =>
      _pastedImageFrom(await _invoke('image'));

  Future<PastedImage?> readImageFile(String path) async => _pastedImageFrom(
    await _invoke('imageFile', <String, Object?>{'path': path}),
  );

  Future<Map<Object?, Object?>?> _invoke(
    String method, [
    Object? arguments,
  ]) async {
    try {
      return await _channel.invokeMethod<Map<Object?, Object?>>(
        method,
        arguments,
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}

PasteboardImageType? _imageTypeNamed(Object? name) {
  for (final PasteboardImageType type in PasteboardImageType.values) {
    if (type.name == name) {
      return type;
    }
  }
  return null;
}

PastedImage? _pastedImageFrom(Map<Object?, Object?>? answer) {
  final Object? bytes = answer?['bytes'];
  final Object? mime = answer?['mime'];
  if (bytes is! Uint8List || mime is! String) {
    return null;
  }
  return PastedImage(bytes: bytes, mime: mime);
}
