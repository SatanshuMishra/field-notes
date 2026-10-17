import 'package:field_notes/data/media/audio_output.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const MethodChannel _channel = MethodChannel('field_notes/audio_output');

const List<Map<String, String>> _reply = <Map<String, String>>[
  <String, String>{'id': 'a', 'name': 'Speakers'},
  <String, String>{'id': 'b', 'name': 'WH-1000XM5'},
];

void _answer(List<MethodCall> calls, Future<Object?> Function() reply) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, (MethodCall call) {
        calls.add(call);
        return reply();
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

  test('outputs are listed after the system output', () async {
    final List<MethodCall> calls = <MethodCall>[];
    _answer(calls, () async => _reply);

    final List<AudioOutputDevice> outputs = await const AudioOutput(_channel)
        .listOutputs();

    expect(outputs, const <AudioOutputDevice>[
      AudioOutputDevice(id: null, name: 'System output'),
      AudioOutputDevice(id: 'a', name: 'Speakers'),
      AudioOutputDevice(id: 'b', name: 'WH-1000XM5'),
    ]);
    expect(calls, hasLength(1));
    expect(calls.single.method, 'listOutputs');
  });

  test('a missing output falls back', () async {
    final List<MethodCall> calls = <MethodCall>[];
    _answer(calls, () async => _reply);

    final List<AudioOutputDevice> outputs = await const AudioOutput(_channel)
        .listOutputs();

    expect(
      resolveAudioOutput(outputs, 'c'),
      const AudioOutputDevice(id: null, name: 'System output'),
    );
    expect(
      resolveAudioOutput(outputs, 'b'),
      const AudioOutputDevice(id: 'b', name: 'WH-1000XM5'),
    );
  });

  test('a broken reply lists only the system output', () async {
    final List<MethodCall> calls = <MethodCall>[];
    _noPlugin(calls);

    final List<AudioOutputDevice> outputs = await const AudioOutput(_channel)
        .listOutputs();

    expect(outputs, const <AudioOutputDevice>[
      AudioOutputDevice(id: null, name: 'System output'),
    ]);
    expect(calls, hasLength(1));
    expect(calls.single.method, 'listOutputs');
  });

  test(
    'a platform error or a malformed reply lists only the system output',
    () async {
      final List<MethodCall> calls = <MethodCall>[];
      const AudioOutput output = AudioOutput(_channel);
      final List<List<AudioOutputDevice>> listings =
          <List<AudioOutputDevice>>[];

      _answer(calls, () async => throw PlatformException(code: 'unavailable'));
      listings.add(await output.listOutputs());

      _answer(calls, () async => 'Speakers');
      listings.add(await output.listOutputs());

      _answer(
        calls,
        () async => <Object?>[
          <String, String>{'id': 'a', 'name': 'Speakers'},
          <String, Object>{'id': 'b', 'name': 3},
        ],
      );
      listings.add(await output.listOutputs());

      expect(listings, const <List<AudioOutputDevice>>[
        <AudioOutputDevice>[AudioOutputDevice(id: null, name: 'System output')],
        <AudioOutputDevice>[AudioOutputDevice(id: null, name: 'System output')],
        <AudioOutputDevice>[AudioOutputDevice(id: null, name: 'System output')],
      ]);
      expect(calls, hasLength(3));
    },
  );
}
