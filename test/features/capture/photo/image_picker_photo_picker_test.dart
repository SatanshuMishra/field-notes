import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/features/capture/photo/image_picker_photo_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  group('photoMimeForPath', () {
    test('maps known image extensions case-insensitively', () {
      expect(photoMimeForPath('/a/b.JPG'), 'image/jpeg');
      expect(photoMimeForPath('/a/b.jpeg'), 'image/jpeg');
      expect(photoMimeForPath('/a/b.png'), 'image/png');
      expect(photoMimeForPath('/a/b.heic'), 'image/heic');
      expect(photoMimeForPath('/a/b.webp'), 'image/webp');
      expect(photoMimeForPath('/a/b.gif'), 'image/gif');
    });

    test('falls back to jpeg for unknown or missing extensions', () {
      expect(photoMimeForPath('/a/b.dat'), fallbackPhotoMime);
      expect(photoMimeForPath('/a/b'), fallbackPhotoMime);
      expect(fallbackPhotoMime, 'image/jpeg');
    });
  });

  group('photoCaptureFromXFile', () {
    test('prefers the declared mime type when present', () {
      final CaptureFile media =
          photoCaptureFromXFile(XFile('/a/b.dat', mimeType: 'image/png'));
      expect(media.mime, 'image/png');
      expect(media.file.path, '/a/b.dat');
    });

    test('infers the mime type from the path when none is declared', () {
      final CaptureFile media = photoCaptureFromXFile(XFile('/a/b.heic'));
      expect(media.mime, 'image/heic');
      expect(media.file.path, '/a/b.heic');
    });
  });
}
