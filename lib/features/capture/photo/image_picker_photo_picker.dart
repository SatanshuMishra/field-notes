import 'dart:io';

import 'package:field_notes/domain/services/capture_service.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

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

CaptureFile photoCaptureFromXFile(XFile file) {
  final String? declared = file.mimeType;
  final String mime = declared != null && declared.isNotEmpty
      ? declared
      : photoMimeForPath(file.path);
  return CaptureFile(file: File(file.path), mime: mime);
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
      return files.map(photoCaptureFromXFile).toList(growable: false);
    } on PlatformException catch (error) {
      throw PhotoPickException(photoLibraryErrorMessage, cause: error);
    }
  }

  @override
  Future<CaptureMedia?> captureFromCamera() async {
    try {
      final XFile? file = await _picker.pickImage(source: ImageSource.camera);
      return file == null ? null : photoCaptureFromXFile(file);
    } on PlatformException catch (error) {
      throw PhotoPickException(photoCameraErrorMessage, cause: error);
    }
  }
}
