import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:field_notes/features/capture/photo/photo_downscale.dart';
import 'package:field_notes/features/capture/photo/photo_intrinsics.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List orientedFixtureJpeg() => base64Decode(
      '/9j/4QAiRXhpZgAATU0AKgAAAAgAAQESAAMAAAABAAYAAAAAAAD/wAARCAAYADADASIAAhEBAxEB'
      '/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQID'
      'AAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RF'
      'RkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKz'
      'tLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEB'
      'AQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdh'
      'cRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldY'
      'WVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPE'
      'xcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9sAQwATExMTExMgExMgLSAgIC09LS0t'
      'LT1NPT09PT1NXU1NTU1NTV1dXV1dXV1dcHBwcHBwg4ODg4OTk5OTk5OTk5OT/9sAQwEXGBglIyVA'
      'IyNAmWhVaJmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZ'
      '/90ABAAD/9oADAMBAAIRAxEAPwDOooorkPoQqhV+qFetln2/l+p5mYfZ+f6BRRRXrHmH/9DOooor'
      'kPoQqhV+qFetln2/l+p5mYfZ+f6BRRRXrHmH/9k=',
    );

Uint8List orientedWideFixtureJpeg() => base64Decode(
      '/9j/4QAiRXhpZgAATU0AKgAAAAgAAQESAAMAAAABAAYAAAAAAAD/wAARCAAICJgDASIAAhEBAxEB'
      '/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQID'
      'AAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RF'
      'RkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKz'
      'tLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEB'
      'AQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdh'
      'cRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldY'
      'WVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPE'
      'xcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9sAQwATExMTExMgExMgLSAgIC09LS0t'
      'LT1NPT09PT1NXU1NTU1NTV1dXV1dXV1dcHBwcHBwg4ODg4OTk5OTk5OTk5OT/9sAQwEXGBglIyVA'
      'IyNAmWhVaJmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZ'
      '/90ABACK/9oADAMBAAIRAxEAPwDOooorkPoQooooAKKKKACiiigAooooAKKKKACiiigAooooAKKK'
      'KACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAoooo'
      'AKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigA'
      'ooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACi'
      'iigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKK'
      'KACiiigAooooAKgn7VPUE/auvBfxo/10OXGfwpf11K9FFFfQnhhRRRQAUUUUAFFFFABRRRQAUUUU'
      'AFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQA'
      'UUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABR'
      'RRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFF'
      'FABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUU'
      'AFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAf/Z',
    );

Future<Uint8List> pngOfSize(int width, int height) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = const ui.Color(0xFF3366AA),
  );
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width / 3, height / 2),
    ui.Paint()..color = const ui.Color(0xFFEE2277),
  );
  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = await picture.toImage(width, height);
  final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return Uint8List.fromList(data!.buffer.asUint8List());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('downscaleTargetFor', () {
    test('leaves an image inside the target alone', () {
      const PhotoIntrinsics small = PhotoIntrinsics(width: 1600, height: 2048);

      expect(photoNeedsDownscale(small), isFalse);
      expect(downscaleTargetFor(small), small);
    });

    test('scales the long edge to the target and keeps the aspect ratio', () {
      const PhotoIntrinsics landscape =
          PhotoIntrinsics(width: 4032, height: 3024);

      final PhotoIntrinsics target = downscaleTargetFor(landscape);

      expect(photoNeedsDownscale(landscape), isTrue);
      expect(target.width, photoLongEdgeTarget);
      expect(target.height, 1536);
    });

    test('scales a portrait photo by its height', () {
      final PhotoIntrinsics target = downscaleTargetFor(
        const PhotoIntrinsics(width: 3024, height: 4032),
      );

      expect(target.height, photoLongEdgeTarget);
      expect(target.width, 1536);
    });

    test('never rounds a sliver down to zero', () {
      final PhotoIntrinsics target = downscaleTargetFor(
        const PhotoIntrinsics(width: 9000, height: 3),
      );

      expect(target.width, photoLongEdgeTarget);
      expect(target.height, greaterThanOrEqualTo(1));
    });
  });

  group('downscalePhoto', () {
    test('passes a sub-target image through untouched', () async {
      final Uint8List bytes = await pngOfSize(320, 240);

      final DownscaledPhoto result = await downscalePhoto(
        bytes: bytes,
        mime: 'image/jpeg',
        intrinsics: const PhotoIntrinsics(width: 320, height: 240),
      );

      expect(identical(result.bytes, bytes), isTrue);
      expect(result.mime, 'image/jpeg');
      expect(result.width, 320);
      expect(result.height, 240);
    });

    test('is byte-stable across repeated runs for the same input', () async {
      final Uint8List bytes = await pngOfSize(2400, 600);
      const PhotoIntrinsics intrinsics =
          PhotoIntrinsics(width: 2400, height: 600);

      final DownscaledPhoto first = await downscalePhoto(
        bytes: bytes,
        mime: 'image/jpeg',
        intrinsics: intrinsics,
      );
      final DownscaledPhoto second = await downscalePhoto(
        bytes: Uint8List.fromList(bytes),
        mime: 'image/jpeg',
        intrinsics: intrinsics,
      );

      expect(first.bytes, second.bytes);
      expect(first.width, photoLongEdgeTarget);
      expect(first.height, 512);
      expect(first.mime, downscaledPhotoMime);
      expect(
        await readPhotoIntrinsics(first.bytes),
        const PhotoIntrinsics(width: photoLongEdgeTarget, height: 512),
      );
    });

    test('keeps an EXIF-rotated photo upright when it downscales', () async {
      final Uint8List wideBytes = orientedWideFixtureJpeg();
      final PhotoIntrinsics wideIntrinsics =
          await readPhotoIntrinsics(wideBytes);

      expect(wideIntrinsics.width, 8);
      expect(wideIntrinsics.height, 2200);

      final DownscaledPhoto wideResult = await downscalePhoto(
        bytes: wideBytes,
        mime: 'image/jpeg',
        intrinsics: wideIntrinsics,
      );

      expect(wideResult.width, 7);
      expect(wideResult.height, 2048);
      expect(wideResult.mime, downscaledPhotoMime);

      final Uint8List smallBytes = orientedFixtureJpeg();
      final PhotoIntrinsics smallIntrinsics =
          await readPhotoIntrinsics(smallBytes);

      final DownscaledPhoto smallResult = await downscalePhoto(
        bytes: smallBytes,
        mime: 'image/jpeg',
        intrinsics: smallIntrinsics,
      );

      expect(identical(smallResult.bytes, smallBytes), isTrue);
      expect(smallResult.width, 24);
      expect(smallResult.height, 48);
    });
  });
}
