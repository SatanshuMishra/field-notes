import 'dart:io';

import 'package:field_notes/data/media/video_join.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const MethodChannel _channel = MethodChannel('field_notes/video_join');

const String _a =
    r'C:\Users\owner\AppData\Local\Temp\captures\video_segment_1.mp4';
const String _b =
    r'C:\Users\owner\AppData\Local\Temp\captures\video_segment_2.mp4';
const String _c =
    r'C:\Users\owner\AppData\Local\Temp\captures\video_segment_3.mp4';
const String _out =
    r'C:\Users\owner\AppData\Local\Temp\captures\video_join_4.mp4';

void _answer(Future<Object?>? Function(MethodCall call)? handler) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, handler);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<MethodCall> calls = <MethodCall>[];

  setUp(calls.clear);

  tearDown(() => _answer(null));

  test(
    'the video joiner sends two segments in order and returns the joined file',
    () async {
      _answer((MethodCall call) async {
        calls.add(call);
        return _out;
      });

      final File joined = await const VideoJoiner().join(<String>[
        _a,
        _b,
      ], _out);

      expect(calls, hasLength(1));
      expect(calls.single.method, 'join');
      expect(calls.single.arguments, <String, Object?>{
        'segments': <String>[_a, _b],
        'output': _out,
      });
      expect(joined.path, File(_out).path);
    },
  );

  test('the video joiner keeps the order of three segments', () async {
    _answer((MethodCall call) async {
      calls.add(call);
      return _out;
    });

    await const VideoJoiner().join(<String>[_a, _b, _c], _out);

    expect(
      (calls.single.arguments as Map<Object?, Object?>)['segments'],
      <String>[_a, _b, _c],
    );
  });

  test('a failed join becomes a VideoJoinException', () async {
    const VideoJoiner joiner = VideoJoiner();

    _answer((MethodCall call) async {
      throw PlatformException(
        code: 'join-failed',
        message: 'The video parts could not be joined.',
      );
    });
    await expectLater(
      joiner.join(<String>[_a, _b], _out),
      throwsA(isA<VideoJoinException>()),
    );

    _answer(null);
    await expectLater(
      joiner.join(<String>[_a, _b], _out),
      throwsA(isA<VideoJoinException>()),
    );

    _answer((MethodCall call) async => 7);
    await expectLater(
      joiner.join(<String>[_a, _b], _out),
      throwsA(isA<VideoJoinException>()),
    );

    _answer((MethodCall call) async => '');
    await expectLater(
      joiner.join(<String>[_a, _b], _out),
      throwsA(isA<VideoJoinException>()),
    );
  });
}
