import 'package:field_notes/domain/services/capture_service.dart';

const String photoLibraryErrorMessage =
    'Could not open your photo library. Check the app permissions in your '
    'system settings and try again.';
const String photoCameraErrorMessage =
    'Could not open the camera. Check the app permissions in your system '
    'settings and try again.';

class PhotoPickException implements Exception {
  const PhotoPickException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'PhotoPickException: $message'
      : 'PhotoPickException: $message ($cause)';
}

abstract interface class PhotoPicker {
  bool get supportsCamera;

  Future<List<CaptureMedia>> pickFromLibrary();

  Future<CaptureMedia?> captureFromCamera();
}
