import 'package:field_notes/data/media/audio_output.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const MethodChannel _channel = MethodChannel('field_notes/audio_output');

typedef _Reply = Future<Object?> Function(MethodCall call);

void _answer(List<MethodCall> calls, _Reply reply) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, (MethodCall call) {
        calls.add(call);
        return reply(call);
      });
}

void _noPlugin(List<MethodCall> calls) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler(_channel.name, (ByteData? message) async {
        calls.add(const StandardMethodCodec().decodeMethodCall(message));
        return null;
      });
}

void _clear() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
    ..setMockMethodCallHandler(_channel, null)
    ..setMockMessageHandler(_channel.name, null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(_clear);

  test('the output name comes from the platform channel', () async {
    const AudioOutput output = AudioOutput(_channel);
    final List<MethodCall> calls = <MethodCall>[];
    final List<String?> names = <String?>[];

    _answer(calls, (MethodCall call) async => 'MacBook Pro Speakers');
    names.add(await output.defaultOutputName());

    _answer(calls, (MethodCall call) async => null);
    names.add(await output.defaultOutputName());

    _answer(calls, (MethodCall call) async => '');
    names.add(await output.defaultOutputName());

    _answer(
      calls,
      (MethodCall call) async => throw PlatformException(
        code: 'unavailable',
        message: 'No output device.',
      ),
    );
    names.add(await output.defaultOutputName());

    _clear();
    _noPlugin(calls);
    names.add(await output.defaultOutputName());

    _clear();
    _answer(calls, (MethodCall call) async => 3);
    names.add(await output.defaultOutputName());

    expect(names, <String?>[
      'MacBook Pro Speakers',
      null,
      null,
      null,
      null,
      null,
    ]);
    expect(calls, hasLength(6));
    for (final MethodCall call in calls) {
      expect(call.method, 'defaultOutputName');
    }
  });

  test('sound settings are opened by the runner', () async {
    const AudioOutput output = AudioOutput(_channel);
    final List<MethodCall> calls = <MethodCall>[];

    _answer(calls, (MethodCall call) async => null);
    await expectLater(output.openSoundSettings(), completes);

    _answer(
      calls,
      (MethodCall call) async => throw PlatformException(
        code: 'unavailable',
        message: 'Settings did not open.',
      ),
    );
    await expectLater(output.openSoundSettings(), completes);

    _clear();
    _noPlugin(calls);
    await expectLater(output.openSoundSettings(), completes);

    expect(calls, hasLength(3));
    for (final MethodCall call in calls) {
      expect(call.method, 'openSoundSettings');
      expect(call.arguments, isNull);
    }
  });
}
