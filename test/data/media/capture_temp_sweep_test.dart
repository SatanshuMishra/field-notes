import 'dart:io';

import 'package:field_notes/data/media/capture_temp_sweep.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const String _pickerFolder = '0f8e2c1a-5b7d-4c3e-9a1b-2d4f6e8a0c1b';
const String _otherUuidFolder = 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d';

File _write(Directory directory, String relative) {
  final File file = File(p.join(directory.path, relative));
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(<int>[1, 2, 3]);
  return file;
}

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('capture_temp_sweep_');
  });

  tearDown(() async {
    if (await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  test(
      "the sweep deletes the app's own temporary capture files and nothing "
      'else', () async {
    final List<File> captures = <File>[
      _write(temp, 'voice_1720000000000.m4a'),
      _write(temp, 'video_thumb_1720000000000.jpg'),
      _write(temp, 'output.mp4'),
      _write(temp, 'REC4471928344313816437.mp4'),
      _write(temp, 'CAP1938274650192837465.jpg'),
      _write(temp, p.join(_pickerFolder, 'IMG_2041.jpg')),
      _write(temp, 'field-notes-export-20260927-101500.zip'),
    ];
    final List<File> kept = <File>[
      _write(temp, 'notes.txt'),
      _write(temp, 'photo.jpg'),
      _write(temp, p.join(_otherUuidFolder, 'readme.txt')),
    ];

    final int removed = await sweepCaptureTemp(temp);

    expect(removed, captures.length);
    for (final File capture in captures) {
      expect(capture.existsSync(), isFalse, reason: capture.path);
    }
    for (final File file in kept) {
      expect(file.existsSync(), isTrue, reason: file.path);
    }
    expect(Directory(p.join(temp.path, _pickerFolder)).existsSync(), isFalse);
    expect(Directory(p.join(temp.path, _otherUuidFolder)).existsSync(), isTrue);
  });

  test("the sweep never touches a file outside the app's temporary folders",
      () async {
    final Directory outside =
        await Directory.systemTemp.createTemp('capture_temp_outside_');
    addTearDown(() => outside.delete(recursive: true));
    final File recording = _write(outside, 'voice_1720000000000.m4a');
    final File picked = _write(outside, p.join('picks', 'IMG_2041.jpg'));
    final Link fileLink = Link(p.join(temp.path, 'voice_1720000000001.m4a'))
      ..createSync(recording.path);
    final Link folderLink = Link(p.join(temp.path, _pickerFolder))
      ..createSync(picked.parent.path);

    final int removed = await sweepCaptureTemp(temp);

    expect(removed, 0);
    expect(recording.existsSync(), isTrue);
    expect(picked.existsSync(), isTrue);
    expect(fileLink.existsSync(), isTrue);
    expect(folderLink.existsSync(), isTrue);
  });
}
