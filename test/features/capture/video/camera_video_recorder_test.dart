import 'dart:io';

import 'package:field_notes/features/capture/platform/camera_video_recorder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('video media formats', () {
    test('records mp4 video and captures a jpeg thumbnail', () {
      expect(videoRecordingMime, 'video/mp4');
      expect(videoRecordingExtension, 'mp4');
      expect(videoThumbnailMime, 'image/jpeg');
      expect(videoThumbnailExtension, 'jpg');
    });
  });

  group('videoRecordingFileName', () {
    test('builds a timestamped video file name with the recording extension', () {
      expect(videoRecordingFileName(1720000000000), 'video_1720000000000.mp4');
    });

    test('produces distinct names for distinct timestamps', () {
      expect(videoRecordingFileName(1) == videoRecordingFileName(2), isFalse);
    });
  });

  group('videoThumbnailFileName', () {
    test('builds a timestamped thumbnail file name with the jpeg extension', () {
      expect(videoThumbnailFileName(1720000000000), 'video_thumb_1720000000000.jpg');
    });

    test('is distinct from the video file name for the same timestamp', () {
      expect(videoThumbnailFileName(5) == videoRecordingFileName(5), isFalse);
    });
  });

  group('resolveVideoThumbnailPath', () {
    test('creates the target directory when it does not exist', () async {
      final Directory base =
          await Directory.systemTemp.createTemp('video_thumb_test_');
      addTearDown(() => base.delete(recursive: true));
      final Directory missing =
          Directory(p.join(base.path, 'nested', 'caches', 'bundle'));
      expect(missing.existsSync(), isFalse);

      final String path = await resolveVideoThumbnailPath(missing, 1720000000000);

      expect(missing.existsSync(), isTrue);
      expect(path, p.join(missing.path, 'video_thumb_1720000000000.jpg'));
    });

    test('returns a path inside an already-existing directory', () async {
      final Directory base =
          await Directory.systemTemp.createTemp('video_thumb_test_');
      addTearDown(() => base.delete(recursive: true));

      final String path = await resolveVideoThumbnailPath(base, 42);

      expect(base.existsSync(), isTrue);
      expect(path, p.join(base.path, 'video_thumb_42.jpg'));
    });
  });
}
