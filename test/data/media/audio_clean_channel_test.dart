import 'package:field_notes/data/media/audio_clean_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const MethodChannel _channel = MethodChannel('field_notes/audio_clean');
const String _input = '/journal/media/ab/abcdef.mp4';
const String _audio = '/tmp/clean/abcdef.wav';
const String _output = '/tmp/clean/abcdef-clean.mp4';

TestDefaultBinaryMessenger get _messenger =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => _messenger.setMockMethodCallHandler(_channel, null));

  test('decodeAudio returns the decoded WAV\'s shape', () async {
    final List<MethodCall> calls = <MethodCall>[];
    _messenger.setMockMethodCallHandler(_channel, (MethodCall call) async {
      calls.add(call);
      return <String, Object?>{
        'sampleRate': 44100,
        'channels': 1,
        'frames': 88200,
      };
    });

    final DecodedAudio decoded = await const AudioCleanChannel().decodeAudio(
      _input,
      _audio,
    );

    expect(calls, hasLength(1));
    expect(calls.single.method, 'decodeAudio');
    expect(calls.single.arguments, <String, Object?>{
      'input': _input,
      'output': _audio,
    });
    expect(decoded.sampleRate, 44100);
    expect(decoded.channels, 1);
    expect(decoded.frames, 88200);
  });

  test('replaceAudio returns the written file', () async {
    final List<MethodCall> calls = <MethodCall>[];
    _messenger.setMockMethodCallHandler(_channel, (MethodCall call) async {
      calls.add(call);
      return _output;
    });

    final file = await const AudioCleanChannel().replaceAudio(
      _input,
      _audio,
      _output,
      96000,
    );

    expect(calls, hasLength(1));
    expect(calls.single.method, 'replaceAudio');
    expect(calls.single.arguments, <String, Object?>{
      'input': _input,
      'audio': _audio,
      'output': _output,
      'bitRate': 96000,
    });
    expect(file.path, _output);
  });

  test('bad clean replies become AudioCleanException', () async {
    final Map<String, Object? Function()?> decodeReplies =
        <String, Object? Function()?>{
          'a platform exception': () =>
              throw PlatformException(code: 'clean-failed'),
          'no handler': null,
          'a zero sample rate': () => <String, Object?>{
            'sampleRate': 0,
            'channels': 1,
            'frames': 5,
          },
          'a missing key': () => <String, Object?>{'channels': 1, 'frames': 5},
        };
    for (final MapEntry<String, Object? Function()?> reply
        in decodeReplies.entries) {
      final Object? Function()? answer = reply.value;
      _messenger.setMockMethodCallHandler(
        _channel,
        answer == null ? null : (MethodCall call) async => answer(),
      );

      await expectLater(
        const AudioCleanChannel().decodeAudio(_input, _audio),
        throwsA(isA<AudioCleanException>()),
        reason: 'decode: ${reply.key}',
      );
    }

    final Map<String, Object? Function()?> replaceReplies =
        <String, Object? Function()?>{
          'a platform exception': () =>
              throw PlatformException(code: 'clean-failed'),
          'no handler': null,
          'an empty string': () => '',
          'a number': () => 4,
        };
    for (final MapEntry<String, Object? Function()?> reply
        in replaceReplies.entries) {
      final Object? Function()? answer = reply.value;
      _messenger.setMockMethodCallHandler(
        _channel,
        answer == null ? null : (MethodCall call) async => answer(),
      );

      await expectLater(
        const AudioCleanChannel().replaceAudio(_input, _audio, _output, 96000),
        throwsA(isA<AudioCleanException>()),
        reason: 'replace: ${reply.key}',
      );
    }
  });
}
