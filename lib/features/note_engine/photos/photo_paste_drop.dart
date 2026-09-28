import 'dart:async';

import 'package:field_notes/domain/services/capture_service.dart'
    show CaptureBytes, CaptureMedia;
import 'package:field_notes/features/capture/photo/image_picker_photo_picker.dart'
    show photoCaptureFromXFile;
import 'package:field_notes/features/capture/photo/photo_downscale.dart'
    show DownscaledPhoto, downscalePhoto;
import 'package:field_notes/features/capture/photo/photo_intrinsics.dart'
    show PhotoIntrinsics, readPhotoIntrinsics, undecodablePhotoMessage;
import 'package:field_notes/features/capture/photo/photo_picker.dart'
    show PhotoPickException;
import 'package:field_notes/features/note_engine/photos/photo_drag.dart';
import 'package:field_notes/features/note_engine/photos/photo_import_flow.dart';
import 'package:field_notes/features/note_engine/platform/android_clipboard_image.dart';
import 'package:field_notes/features/note_engine/platform/image_pasteboard.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart' show XFile;

typedef PhotoMediaImporter = Future<String> Function(CaptureMedia photo);

typedef PhotoCaptureFromPath = Future<CaptureMedia> Function(String path);

typedef PhotoCaptureFromBytes =
    Future<CaptureMedia> Function(Uint8List bytes, String mime);

const Map<String, String> photoFileMimeTypes = <String, String>{
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'heic': 'image/heic',
  'gif': 'image/gif',
  'webp': 'image/webp',
  'tiff': 'image/tiff',
};

const Set<String> macosConvertedPhotoExtensions = <String>{'heic', 'tiff'};

String? _extensionOf(String path) {
  final String segment = path.substring(path.lastIndexOf('/') + 1);
  final int dot = segment.lastIndexOf('.');
  return dot < 0 ? null : segment.substring(dot + 1).toLowerCase();
}

bool isPhotoFilePath(String path) =>
    photoFileMimeTypes.containsKey(_extensionOf(path));

String skippedFilesToastMessage(int count) => count == 1
    ? '1 file skipped — only photos can be added to a note'
    : '$count files skipped — only photos can be added to a note';

sealed class PhotoPastePlan {
  const PhotoPastePlan();
}

final class PastePhotoFiles extends PhotoPastePlan {
  const PastePhotoFiles({required this.paths, required this.skipped});

  final List<String> paths;
  final int skipped;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PastePhotoFiles &&
          skipped == other.skipped &&
          listEquals(paths, other.paths);

  @override
  int get hashCode => Object.hash(Object.hashAll(paths), skipped);

  @override
  String toString() => 'PastePhotoFiles($paths, skipped: $skipped)';
}

final class PastePhotoData extends PhotoPastePlan {
  const PastePhotoData();

  @override
  bool operator ==(Object other) => other is PastePhotoData;

  @override
  int get hashCode => (PastePhotoData).hashCode;

  @override
  String toString() => 'PastePhotoData()';
}

final class PastePlainText extends PhotoPastePlan {
  const PastePlainText();

  @override
  bool operator ==(Object other) => other is PastePlainText;

  @override
  int get hashCode => (PastePlainText).hashCode;

  @override
  String toString() => 'PastePlainText()';
}

PhotoPastePlan planMacosPaste(PasteboardContents contents) {
  final List<String> photos = List<String>.unmodifiable(
    contents.filePaths.where(isPhotoFilePath),
  );
  if (photos.isNotEmpty) {
    return PastePhotoFiles(
      paths: photos,
      skipped: contents.filePaths.length - photos.length,
    );
  }
  if (contents.hasImageData && !contents.hasText) {
    return const PastePhotoData();
  }
  return const PastePlainText();
}

Future<CaptureMedia> photoCaptureFromPath(String path) => photoCaptureFromXFile(
  XFile(path, mimeType: photoFileMimeTypes[_extensionOf(path)]),
);

Future<CaptureMedia> photoCaptureFromBytes(Uint8List bytes, String mime) async {
  final PhotoIntrinsics intrinsics = await readPhotoIntrinsics(bytes);
  final DownscaledPhoto scaled = await downscalePhoto(
    bytes: bytes,
    mime: mime,
    intrinsics: intrinsics,
  );
  return CaptureBytes(
    bytes: scaled.bytes,
    mime: scaled.mime,
    width: scaled.width,
    height: scaled.height,
  );
}

final class PhotoPasteDrop extends ChangeNotifier {
  PhotoPasteDrop({
    required this._platform,
    required this._imports,
    required this._importPhoto,
    required this._dropTargets,
    required this._onSkipped,
    this._pasteboard = const ImagePasteboard(),
    this._androidClipboard = const AndroidClipboardImage(),
    this._captureFromPath = photoCaptureFromPath,
    this._captureFromBytes = photoCaptureFromBytes,
  });

  final TargetPlatform _platform;
  final PhotoImportFlow _imports;
  final PhotoMediaImporter _importPhoto;
  final List<PhotoDropTarget> Function() _dropTargets;
  final void Function(String message) _onSkipped;
  final ImagePasteboard _pasteboard;
  final AndroidClipboardImage _androidClipboard;
  final PhotoCaptureFromPath _captureFromPath;
  final PhotoCaptureFromBytes _captureFromBytes;
  PhotoDropTarget? _hoverTarget;

  PhotoDropTarget? get hoverTarget => _hoverTarget;

  Future<bool> paste() async {
    switch (_platform) {
      case TargetPlatform.macOS:
        return _pasteOnMacos();
      case TargetPlatform.android:
        if (!await _androidClipboard.hasImage()) {
          return false;
        }
        _startAtCaret(() => _importPasted(_androidClipboard.readImage));
        return true;
      case TargetPlatform.fuchsia:
      case TargetPlatform.iOS:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return false;
    }
  }

  void hover(Offset position) =>
      _setHover(nearestPhotoDropTarget(_dropTargets(), position.dy));

  void leave() => _setHover(null);

  Future<void> drop(Offset position, List<String> paths) async {
    final List<String> photos = List<String>.unmodifiable(
      paths.where(isPhotoFilePath),
    );
    final int skipped = paths.length - photos.length;
    if (skipped > 0) {
      _onSkipped(skippedFilesToastMessage(skipped));
    }
    final PhotoDropTarget? target = nearestPhotoDropTarget(
      _dropTargets(),
      position.dy,
    );
    _setHover(null);
    if (photos.isEmpty || target == null) {
      return;
    }
    unawaited(
      _imports.importAtBoundary(target.boundary, () => _importPaths(photos)),
    );
  }

  Future<bool> insertKeyboardContent(KeyboardInsertedContent content) async {
    final String mime = content.mimeType;
    final Uint8List? data = content.data;
    if (!mime.startsWith('image/') || data == null || data.isEmpty) {
      return false;
    }
    _startAtCaret(
      () async => <String>[
        await _importPhoto(await _captureFromBytes(data, mime)),
      ],
    );
    return true;
  }

  Future<bool> _pasteOnMacos() async {
    final PhotoPastePlan plan = planMacosPaste(
      await _pasteboard.readContents(),
    );
    switch (plan) {
      case PastePhotoFiles(
        paths: final List<String> paths,
        skipped: final int skipped,
      ):
        if (skipped > 0) {
          _onSkipped(skippedFilesToastMessage(skipped));
        }
        _startAtCaret(() => _importPaths(paths));
        return true;
      case PastePhotoData():
        _startAtCaret(() => _importPasted(_pasteboard.readImage));
        return true;
      case PastePlainText():
        return false;
    }
  }

  void _startAtCaret(PhotoReferenceLoader load) =>
      unawaited(_imports.importAtCaret(load));

  Future<List<String>> _importPasted(
    Future<PastedImage?> Function() read,
  ) async {
    final PastedImage image = _readable(await read());
    return <String>[
      await _importPhoto(await _captureFromBytes(image.bytes, image.mime)),
    ];
  }

  Future<List<String>> _importPaths(List<String> paths) async {
    List<String> references = const <String>[];
    for (final String path in paths) {
      final CaptureMedia capture = await _capturePath(path);
      references = <String>[...references, await _importPhoto(capture)];
    }
    return List<String>.unmodifiable(references);
  }

  Future<CaptureMedia> _capturePath(String path) async {
    if (_platform == TargetPlatform.macOS &&
        macosConvertedPhotoExtensions.contains(_extensionOf(path))) {
      final PastedImage image = _readable(
        await _pasteboard.readImageFile(path),
      );
      return _captureFromBytes(image.bytes, image.mime);
    }
    return _captureFromPath(path);
  }

  PastedImage _readable(PastedImage? image) =>
      image ?? (throw const PhotoPickException(undecodablePhotoMessage));

  void _setHover(PhotoDropTarget? target) {
    if (target == _hoverTarget) {
      return;
    }
    _hoverTarget = target;
    notifyListeners();
  }
}
