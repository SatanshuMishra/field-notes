import 'package:field_notes/data/media/audio_peaks_decoder.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const MethodChannel _channel = MethodChannel('field_notes/audio_peaks');
const String _path = '/journal/media/ab/abcdef.m4a';

TestDefaultBinaryMessenger get _messenger =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => _messenger.setMockMethodCallHandler(_channel, null));

  test('the decoder asks the platform for 100 ms windows', () async {
    final List<MethodCall> calls = <MethodCall>[];
    _messenger.setMockMethodCallHandler(_channel, (MethodCall call) async {
      calls.add(call);
      return <double>[0.1, 0.2];
    });

    final List<double> rms = await const AudioPeaksDecoder().windowRms(_path);

    expect(calls, hasLength(1));
    expect(calls.single.method, 'windowRms');
    expect(calls.single.arguments, <String, Object?>{
      'path': _path,
      'windowMs': 100,
    });
    expect(rms, <double>[0.1, 0.2]);
  });

  test('a bad platform answer is a failure', () async {
    final Map<String, Object? Function()> answers =
        <String, Object? Function()>{
          'a platform exception': () =>
              throw PlatformException(code: 'decode-failed'),
          'a map': () => <String, Object?>{
            'rms': <double>[0.1],
          },
          'a negative value': () => <Object?>[-1],
          'a value that is not a number': () => <Object?>[double.nan],
        };
    for (final MapEntry<String, Object? Function()> answer in answers.entries) {
      _messenger.setMockMethodCallHandler(
        _channel,
        (MethodCall call) async => answer.value(),
      );

      await expectLater(
        const AudioPeaksDecoder().windowRms(_path),
        throwsA(isA<AudioPeaksDecodeException>()),
        reason: answer.key,
      );
    }
  });
}
