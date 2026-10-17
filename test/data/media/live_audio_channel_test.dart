import 'package:field_notes/data/media/live_audio_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const MethodChannel _channel = MethodChannel('field_notes/live_audio');

TestDefaultBinaryMessenger get _messenger =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => _messenger.setMockMethodCallHandler(_channel, null));

  test('an encoder opens, appends and closes', () async {
    final List<MethodCall> calls = <MethodCall>[];
    _messenger.setMockMethodCallHandler(_channel, (MethodCall call) async {
      calls.add(call);
      return switch (call.method) {
        'openEncoder' => 7,
        'closeEncoder' => '/tmp/a.m4a',
        _ => null,
      };
    });
    final Uint8List pcm = Uint8List.fromList(<int>[1, 0, 2, 0]);

    const LiveEncoder encoder = LiveEncoder();
    final int id = await encoder.open(
      path: '/tmp/a.m4a',
      sampleRate: 48000,
      channels: 1,
      bitRate: 64000,
    );
    await encoder.append(id, pcm);
    final String written = await encoder.close(id);

    expect(id, 7);
    expect(written, '/tmp/a.m4a');
    expect(calls.map((MethodCall call) => call.method).toList(), <String>[
      'openEncoder',
      'appendPcm',
      'closeEncoder',
    ]);
    expect(calls[0].arguments, <String, Object?>{
      'path': '/tmp/a.m4a',
      'sampleRate': 48000,
      'channels': 1,
      'bitRate': 64000,
    });
    expect(calls[1].arguments, <String, Object?>{'id': 7, 'pcm': pcm});
    expect(calls[2].arguments, <String, Object?>{'id': 7});
  });

  test('a join answers the written file', () async {
    final List<MethodCall> calls = <MethodCall>[];
    _messenger.setMockMethodCallHandler(_channel, (MethodCall call) async {
      calls.add(call);
      return '/tmp/out.mp4';
    });

    final String written = await const AudioJoiner().join(
      video: '/tmp/in.mp4',
      audio: '/tmp/in.m4a',
      output: '/tmp/out.mp4',
    );

    expect(written, '/tmp/out.mp4');
    expect(calls, hasLength(1));
    expect(calls.single.method, 'joinAudio');
    expect(calls.single.arguments, <String, Object?>{
      'video': '/tmp/in.mp4',
      'audio': '/tmp/in.m4a',
      'output': '/tmp/out.mp4',
    });
  });

  test('platform failures are named', () async {
    _messenger.setMockMethodCallHandler(_channel, (MethodCall call) async {
      throw PlatformException(code: 'encode-failed');
    });

    await expectLater(
      const LiveEncoder().append(7, Uint8List(4)),
      throwsA(
        isA<LiveAudioException>().having(
          (LiveAudioException error) => error.message,
          'message',
          contains('appendPcm'),
        ),
      ),
    );
  });
}
