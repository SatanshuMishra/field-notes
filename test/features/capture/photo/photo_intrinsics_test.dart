import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:field_notes/features/capture/photo/photo_intrinsics.dart';
import 'package:field_notes/features/capture/photo/photo_picker.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List wideFixturePng() => base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAEAAAAAwCAIAAAAuKetIAAAAQ0lEQVR42u'
      '3PQQkAAAgEsOtkJ8OZ0gp+hcEKLNXzWgQEBAQEBAQEBAQEBAQEBAQEBAQE'
      'BAQEBAQEBAQEBAQEBAQErhb+AyTiX+wqigAAAABJRU5ErkJggg==',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('fn_intrinsics');
  });

  tearDown(() async {
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  group('readPhotoIntrinsics', () {
    test('reports the encoded dimensions without decoding the pixels',
        () async {
      final PhotoIntrinsics intrinsics =
          await readPhotoIntrinsics(wideFixturePng());

      expect(intrinsics.width, 64);
      expect(intrinsics.height, 48);
      expect(intrinsics.longEdge, 64);
    });

    test('an undecodable header throws at pick time', () async {
      await expectLater(
        readPhotoIntrinsics(Uint8List.fromList(<int>[0, 1, 2, 3, 4, 5, 6, 7])),
        throwsA(
          isA<PhotoPickException>().having(
            (PhotoPickException e) => e.message,
            'message',
            undecodablePhotoMessage,
          ),
        ),
      );
    });

    test('an empty buffer throws rather than reporting a zero-sized photo',
        () async {
      await expectLater(
        readPhotoIntrinsics(Uint8List(0)),
        throwsA(isA<PhotoPickException>()),
      );
    });
  });

  group('readPhotoIntrinsicsOfFile', () {
    test('reads the dimensions straight off the file', () async {
      final File file = File('${dir.path}/wide.png');
      await file.writeAsBytes(wideFixturePng());

      final PhotoIntrinsics intrinsics = await readPhotoIntrinsicsOfFile(file);

      expect(intrinsics, const PhotoIntrinsics(width: 64, height: 48));
    });

    test('a file with a corrupt header throws at pick time', () async {
      final File file = File('${dir.path}/broken.heic');
      await file.writeAsBytes(<int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);

      await expectLater(
        readPhotoIntrinsicsOfFile(file),
        throwsA(isA<PhotoPickException>()),
      );
    });

    test('a missing file throws at pick time', () async {
      await expectLater(
        readPhotoIntrinsicsOfFile(File('${dir.path}/absent.jpg')),
        throwsA(isA<PhotoPickException>()),
      );
    });
  });
}
