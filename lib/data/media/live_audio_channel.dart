import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String liveAudioChannelName = 'field_notes/live_audio';
const String openEncoderMethod = 'openEncoder';
const String appendPcmMethod = 'appendPcm';
const String closeEncoderMethod = 'closeEncoder';
const String cancelEncoderMethod = 'cancelEncoder';
const String joinAudioMethod = 'joinAudio';

class LiveAudioException implements Exception {
  const LiveAudioException(this.method, [this.cause]);

  final String method;
  final Object? cause;

  String get message => 'Live audio $method failed';

  @override
  String toString() => 'LiveAudioException: $message ($cause)';
}

Future<T?> _invoke<T>(
  MethodChannel channel,
  String method,
  Map<String, Object?> arguments,
) async {
  try {
    return await channel.invokeMethod<T>(method, arguments);
  } on PlatformException catch (error) {
    throw LiveAudioException(method, error);
  } on MissingPluginException catch (error) {
    throw LiveAudioException(method, error);
  }
}

Future<String> _invokeForPath(
  MethodChannel channel,
  String method,
  Map<String, Object?> arguments,
) async {
  final Object? reply = await _invoke<Object?>(channel, method, arguments);
  if (reply is! String) {
    throw LiveAudioException(method, reply);
  }
  return reply;
}

class LiveEncoder {
  const LiveEncoder([
    this._channel = const MethodChannel(liveAudioChannelName),
  ]);

  final MethodChannel _channel;

  Future<int> open({
    required String path,
    required int sampleRate,
    required int channels,
    required int bitRate,
  }) async {
    final Object? reply = await _invoke<Object?>(
      _channel,
      openEncoderMethod,
      <String, Object?>{
        'path': path,
        'sampleRate': sampleRate,
        'channels': channels,
        'bitRate': bitRate,
      },
    );
    if (reply is! int) {
      throw LiveAudioException(openEncoderMethod, reply);
    }
    return reply;
  }

  Future<void> append(int id, Uint8List pcm) async {
    await _invoke<void>(_channel, appendPcmMethod, <String, Object?>{
      'id': id,
      'pcm': pcm,
    });
  }

  Future<String> close(int id) =>
      _invokeForPath(_channel, closeEncoderMethod, <String, Object?>{'id': id});

  Future<void> cancel(int id) async {
    await _invoke<void>(_channel, cancelEncoderMethod, <String, Object?>{
      'id': id,
    });
  }
}

class AudioJoiner {
  const AudioJoiner([
    this._channel = const MethodChannel(liveAudioChannelName),
  ]);

  final MethodChannel _channel;

  Future<String> join({
    required String video,
    required String audio,
    required String output,
  }) => _invokeForPath(_channel, joinAudioMethod, <String, Object?>{
    'video': video,
    'audio': audio,
    'output': output,
  });
}

final Provider<LiveEncoder> liveEncoderProvider = Provider<LiveEncoder>(
  (Ref ref) => const LiveEncoder(),
);

final Provider<AudioJoiner> audioJoinerProvider = Provider<AudioJoiner>(
  (Ref ref) => const AudioJoiner(),
);
