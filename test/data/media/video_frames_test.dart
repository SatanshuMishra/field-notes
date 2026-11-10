import 'dart:async';

import 'package:field_notes/data/media/video_frames.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const MethodChannel _channel = MethodChannel('field_notes/video_frames');

const String _clip = '/journal/media/ab/abcdef.mp4';
const String _otherClip = '/journal/media/cd/cdef01.mp4';

void _answer(Future<Object?>? Function(MethodCall call)? handler) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, handler);
}

int _positionMs(MethodCall call) =>
    (call.arguments as Map<Object?, Object?>)['positionMs']! as int;

Uint8List _jpegAt(int positionMs) =>
    Uint8List.fromList(<int>[0xFF, 0xD8, positionMs ~/ 1000, 0xFF, 0xD9]);

Duration _seconds(int seconds) => Duration(seconds: seconds);

VideoFrames _frames() {
  final ProviderContainer container = ProviderContainer();
  addTearDown(container.dispose);
  return container.read(videoFramesProvider);
}

Future<void> _visitSeconds(VideoFrames frames, int count) async {
  for (int second = 0; second < count; second += 1) {
    await frames.frameAt(_clip, _seconds(second));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<MethodCall> calls = <MethodCall>[];
  final List<Completer<Object?>> heldReplies = <Completer<Object?>>[];

  void answerEveryCall() {
    _answer((MethodCall call) async {
      calls.add(call);
      return _jpegAt(_positionMs(call));
    });
  }

  void holdEveryReply() {
    _answer((MethodCall call) {
      calls.add(call);
      final Completer<Object?> reply = Completer<Object?>();
      heldReplies.add(reply);
      return reply.future;
    });
  }

  setUp(() {
    calls.clear();
    heldReplies.clear();
  });

  tearDown(() => _answer(null));

  test(
    'asks the platform for a frame 320 wide and returns its bytes',
    () async {
      answerEveryCall();

      final Uint8List? frame = await _frames().frameAt(_clip, _seconds(7));

      expect(calls, hasLength(1));
      expect(calls.single.method, 'frameAt');
      expect(calls.single.arguments, <String, Object?>{
        'path': _clip,
        'positionMs': 7000,
        'width': 320,
      });
      expect(frame, _jpegAt(7000));
    },
  );

  group('whole-second keys', () {
    test('positions inside one second share the frame at its start', () async {
      answerEveryCall();
      final VideoFrames frames = _frames();

      final Uint8List? early = await frames.frameAt(
        _clip,
        const Duration(milliseconds: 5100),
      );
      final Uint8List? late = await frames.frameAt(
        _clip,
        const Duration(milliseconds: 5900),
      );

      expect(calls.map(_positionMs), <int>[5000]);
      expect(early, _jpegAt(5000));
      expect(late, _jpegAt(5000));
    });

    test('the next second and another file each get their own frame', () async {
      answerEveryCall();
      final VideoFrames frames = _frames();

      await frames.frameAt(_clip, const Duration(milliseconds: 5900));
      await frames.frameAt(_clip, const Duration(milliseconds: 6000));
      await frames.frameAt(_otherClip, const Duration(milliseconds: 5900));

      expect(
        calls.map((MethodCall call) {
          final Map<Object?, Object?> arguments =
              call.arguments as Map<Object?, Object?>;
          return (arguments['path'], arguments['positionMs']);
        }),
        <(Object?, Object?)>[(_clip, 5000), (_clip, 6000), (_otherClip, 5000)],
      );
    });

    test('a position before the start asks for the first second', () async {
      answerEveryCall();

      await _frames().frameAt(_clip, const Duration(seconds: -3));

      expect(calls.map(_positionMs), <int>[0]);
    });
  });

  group('cache limit', () {
    test('keeps the most recent 120 frames and forgets older ones', () async {
      answerEveryCall();
      final VideoFrames frames = _frames();
      await _visitSeconds(frames, 121);
      calls.clear();

      await frames.frameAt(_clip, _seconds(1));
      await frames.frameAt(_clip, _seconds(120));
      expect(calls, isEmpty);

      await frames.frameAt(_clip, _seconds(0));
      expect(calls.map(_positionMs), <int>[0]);
    });

    test('a frame shown again counts as recent', () async {
      answerEveryCall();
      final VideoFrames frames = _frames();
      await _visitSeconds(frames, 120);
      await frames.frameAt(_clip, _seconds(0));
      await frames.frameAt(_clip, _seconds(120));
      calls.clear();

      await frames.frameAt(_clip, _seconds(0));
      expect(calls, isEmpty);

      await frames.frameAt(_clip, _seconds(1));
      expect(calls.map(_positionMs), <int>[1000]);
    });
  });

  group('superseded requests', () {
    test(
      'one passed over while another runs never reaches the platform',
      () async {
        holdEveryReply();
        final VideoFrames frames = _frames();

        unawaited(frames.frameAt(_clip, _seconds(1)));
        await pumpEventQueue();
        final Future<Uint8List?> passedOver = frames.frameAt(
          _clip,
          _seconds(2),
        );
        final Future<Uint8List?> newest = frames.frameAt(_clip, _seconds(3));

        expect(await passedOver, isNull);
        expect(calls.map(_positionMs), <int>[1000]);

        heldReplies.first.complete(_jpegAt(1000));
        await pumpEventQueue();
        expect(calls.map(_positionMs), <int>[1000, 3000]);

        heldReplies.last.complete(_jpegAt(3000));
        expect(await newest, _jpegAt(3000));
      },
    );

    test('a running one answers null but its frame is kept', () async {
      holdEveryReply();
      final VideoFrames frames = _frames();

      final Future<Uint8List?> superseded = frames.frameAt(_clip, _seconds(1));
      await pumpEventQueue();
      final Future<Uint8List?> newest = frames.frameAt(_clip, _seconds(2));

      heldReplies.first.complete(_jpegAt(1000));
      expect(await superseded, isNull);
      await pumpEventQueue();
      heldReplies.last.complete(_jpegAt(2000));
      await newest;
      calls.clear();

      expect(await frames.frameAt(_clip, _seconds(1)), _jpegAt(1000));
      expect(calls, isEmpty);
    });

    test('returning to the running second drops the one waiting', () async {
      holdEveryReply();
      final VideoFrames frames = _frames();

      final Future<Uint8List?> running = frames.frameAt(_clip, _seconds(1));
      await pumpEventQueue();
      final Future<Uint8List?> passedOver = frames.frameAt(_clip, _seconds(2));
      final Future<Uint8List?> returned = frames.frameAt(
        _clip,
        const Duration(milliseconds: 1500),
      );

      expect(await passedOver, isNull);

      heldReplies.single.complete(_jpegAt(1000));
      expect(await running, _jpegAt(1000));
      expect(await returned, _jpegAt(1000));
      await pumpEventQueue();
      expect(calls.map(_positionMs), <int>[1000]);
    });

    test('moving to a cached frame drops the one waiting', () async {
      answerEveryCall();
      final VideoFrames frames = _frames();
      await frames.frameAt(_clip, _seconds(9));
      calls.clear();
      holdEveryReply();

      final Future<Uint8List?> running = frames.frameAt(_clip, _seconds(1));
      await pumpEventQueue();
      final Future<Uint8List?> passedOver = frames.frameAt(_clip, _seconds(2));
      final Uint8List? cached = await frames.frameAt(_clip, _seconds(9));

      expect(cached, _jpegAt(9000));
      expect(await passedOver, isNull);

      heldReplies.single.complete(_jpegAt(1000));
      await running;
      await pumpEventQueue();
      expect(calls.map(_positionMs), <int>[1000]);
    });
  });

  group('null on failure', () {
    test('a platform error answers null', () async {
      _answer((MethodCall call) async {
        throw PlatformException(code: 'frame-failed');
      });

      expect(await _frames().frameAt(_clip, _seconds(4)), isNull);
    });

    test('a platform without the channel answers null', () async {
      expect(await _frames().frameAt(_clip, _seconds(4)), isNull);
    });

    test('a reply without usable bytes answers null', () async {
      for (final Object? reply in <Object?>[
        null,
        Uint8List(0),
        'not a frame',
      ]) {
        _answer((MethodCall call) async => reply);

        expect(
          await _frames().frameAt(_clip, _seconds(4)),
          isNull,
          reason: 'reply $reply',
        );
      }
    });

    test(
      'a failure is tried again and does not block later requests',
      () async {
        bool failing = true;
        _answer((MethodCall call) async {
          calls.add(call);
          if (failing) {
            throw PlatformException(code: 'frame-failed');
          }
          return _jpegAt(_positionMs(call));
        });
        final VideoFrames frames = _frames();

        expect(await frames.frameAt(_clip, _seconds(4)), isNull);
        failing = false;

        expect(await frames.frameAt(_clip, _seconds(4)), _jpegAt(4000));
        expect(await frames.frameAt(_clip, _seconds(5)), _jpegAt(5000));
        expect(calls.map(_positionMs), <int>[4000, 4000, 5000]);
      },
    );
  });
}
