import 'dart:io';

import 'package:field_notes/domain/services/capture_service.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'photo_downscale.dart';
import 'photo_intrinsics.dart';
import 'photo_picker.dart';

const String fallbackPhotoMime = 'image/jpeg';

const Map<String, String> _photoMimeByExtension = <String, String>{
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.png': 'image/png',
  '.heic': 'image/heic',
  '.heif': 'image/heif',
  '.webp': 'image/webp',
  '.gif': 'image/gif',
};

String photoMimeForPath(String path) {
  final int dot = path.lastIndexOf('.');
  if (dot < 0) {
    return fallbackPhotoMime;
  }
  final String extension = path.substring(dot).toLowerCase();
  return _photoMimeByExtension[extension] ?? fallbackPhotoMime;
}

Future<CaptureMedia> photoCaptureFromXFile(XFile file) async {
  final String? declared = file.mimeType;
  final String mime = declared != null && declared.isNotEmpty
      ? declared
      : photoMimeForPath(file.path);
  final File source = File(file.path);
  final PhotoIntrinsics intrinsics = await readPhotoIntrinsicsOfFile(source);

  if (!photoNeedsDownscale(intrinsics)) {
    return CaptureFile(
      file: source,
      mime: mime,
      width: intrinsics.width,
      height: intrinsics.height,
    );
  }

  final Uint8List bytes = await source.readAsBytes();
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

class ImagePickerPhotoPicker implements PhotoPicker {
  ImagePickerPhotoPicker({ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  bool get supportsCamera => Platform.isAndroid || Platform.isIOS;

  @override
  Future<List<CaptureMedia>> pickFromLibrary() async {
    try {
      final List<XFile> files = await _picker.pickMultiImage();
      final List<CaptureMedia> picked = <CaptureMedia>[];
      for (final XFile file in files) {
        picked.add(await photoCaptureFromXFile(file));
      }
      return List<CaptureMedia>.unmodifiable(picked);
    } on PlatformException catch (error) {
      throw PhotoPickException(photoLibraryErrorMessage, cause: error);
    }
  }

  @override
  Future<CaptureMedia?> captureFromCamera() async {
    try {
      final XFile? file = await _picker.pickImage(source: ImageSource.camera);
      return file == null ? null : await photoCaptureFromXFile(file);
    } on PlatformException catch (error) {
      throw PhotoPickException(photoCameraErrorMessage, cause: error);
    }
  }
}
