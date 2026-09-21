import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/features/capture/photo/image_picker_photo_picker.dart';
import 'package:field_notes/features/capture/photo/photo_intrinsics.dart';
import 'package:field_notes/features/capture/photo/photo_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

Uint8List _wideFixturePng() => base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAEAAAAAwCAIAAAAuKetIAAAAQ0lEQVR42u'
      '3PQQkAAAgEsOtkJ8OZ0gp+hcEKLNXzWgQEBAQEBAQEBAQEBAQEBAQEBAQE'
      'BAQEBAQEBAQEBAQEBAQErhb+AyTiX+wqigAAAABJRU5ErkJggg==',
    );

class _RecordingImagePicker implements ImagePicker {
  _RecordingImagePicker({this.multi = const <XFile>[], this.single});

  final List<XFile> multi;
  final XFile? single;
  final List<Map<String, Object?>> multiCalls = <Map<String, Object?>>[];
  final List<Map<String, Object?>> singleCalls = <Map<String, Object?>>[];

  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async {
    multiCalls.add(<String, Object?>{
      'maxWidth': maxWidth,
      'maxHeight': maxHeight,
      'imageQuality': imageQuality,
    });
    return multi;
  }

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    singleCalls.add(<String, Object?>{
      'maxWidth': maxWidth,
      'maxHeight': maxHeight,
      'imageQuality': imageQuality,
    });
    return single;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('fn_picker');
  });

  tearDown(() async {
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  Future<File> writeFixture(String name) async {
    final File file = File('${dir.path}/$name');
    await file.writeAsBytes(_wideFixturePng());
    return file;
  }

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
    test('prefers the declared mime type when present', () async {
      final File file = await writeFixture('b.dat');

      final CaptureMedia media = await photoCaptureFromXFile(
        XFile(file.path, mimeType: 'image/png'),
      );

      expect(media.mime, 'image/png');
      expect((media as CaptureFile).file.path, file.path);
    });

    test('infers the mime type from the path when none is declared', () async {
      final File file = await writeFixture('b.png');

      final CaptureMedia media = await photoCaptureFromXFile(XFile(file.path));

      expect(media.mime, 'image/png');
      expect((media as CaptureFile).file.path, file.path);
    });

    test('carries the intrinsic dimensions through to the store call',
        () async {
      final File file = await writeFixture('wide.png');

      final CaptureMedia media = await photoCaptureFromXFile(XFile(file.path));

      expect(media.width, 64);
      expect(media.height, 48);
    });

    test('keeps a sub-target photo byte-identical to the picked original',
        () async {
      final File file = await writeFixture('wide.png');

      final CaptureMedia first =
          await photoCaptureFromXFile(XFile(file.path));
      final CaptureMedia second =
          await photoCaptureFromXFile(XFile(file.path));

      expect(await (first as CaptureFile).file.readAsBytes(),
          _wideFixturePng());
      expect(
        await (first).file.readAsBytes(),
        await (second as CaptureFile).file.readAsBytes(),
      );
    });

    test('an undecodable photo fails loudly at the picker', () async {
      final File file = File('${dir.path}/broken.heic');
      await file.writeAsBytes(<int>[9, 9, 9, 9, 9, 9, 9, 9]);

      await expectLater(
        photoCaptureFromXFile(XFile(file.path)),
        throwsA(
          isA<PhotoPickException>().having(
            (PhotoPickException e) => e.message,
            'message',
            undecodablePhotoMessage,
          ),
        ),
      );
    });
  });

  group('ImagePickerPhotoPicker', () {
    test('picks the original, passing no platform-side downscale arguments',
        () async {
      final File file = await writeFixture('one.png');
      final _RecordingImagePicker picker =
          _RecordingImagePicker(multi: <XFile>[XFile(file.path)]);

      final List<CaptureMedia> picked =
          await ImagePickerPhotoPicker(picker: picker).pickFromLibrary();

      expect(picker.multiCalls, <Map<String, Object?>>[
        <String, Object?>{
          'maxWidth': null,
          'maxHeight': null,
          'imageQuality': null,
        },
      ]);
      expect(picked.single.width, 64);
      expect(picked.single.height, 48);
    });

    test('the camera path also passes no downscale arguments', () async {
      final File file = await writeFixture('shot.png');
      final _RecordingImagePicker picker =
          _RecordingImagePicker(single: XFile(file.path));

      final CaptureMedia? media =
          await ImagePickerPhotoPicker(picker: picker).captureFromCamera();

      expect(picker.singleCalls, <Map<String, Object?>>[
        <String, Object?>{
          'maxWidth': null,
          'maxHeight': null,
          'imageQuality': null,
        },
      ]);
      expect(media?.width, 64);
    });

    test('a cancelled camera capture yields nothing', () async {
      final _RecordingImagePicker picker = _RecordingImagePicker();

      expect(
        await ImagePickerPhotoPicker(picker: picker).captureFromCamera(),
        isNull,
      );
    });
  });
}
