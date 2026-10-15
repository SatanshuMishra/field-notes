import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String audioCleanChannelName = 'field_notes/audio_clean';
const String decodeAudioMethod = 'decodeAudio';
const String replaceAudioMethod = 'replaceAudio';

class AudioCleanException implements Exception {
  const AudioCleanException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'AudioCleanException: $message';
}

class DecodedAudio {
  const DecodedAudio({
    required this.sampleRate,
    required this.channels,
    required this.frames,
  });

  final int sampleRate;
  final int channels;
  final int frames;
}

class AudioCleanChannel {
  const AudioCleanChannel([
    this._channel = const MethodChannel(audioCleanChannelName),
  ]);

  final MethodChannel _channel;

  Future<DecodedAudio> decodeAudio(String input, String output) async {
    final Object? reply = await _invoke(decodeAudioMethod, <String, Object?>{
      'input': input,
      'output': output,
    });
    if (reply is! Map<Object?, Object?>) {
      throw AudioCleanException(
        'expected a decode reply map, got ${reply.runtimeType}',
      );
    }
    final Object? sampleRate = reply['sampleRate'];
    final Object? channels = reply['channels'];
    final Object? frames = reply['frames'];
    if (!_isPositiveInt(sampleRate) ||
        !_isPositiveInt(channels) ||
        !_isPositiveInt(frames)) {
      throw AudioCleanException('the decode reply is incomplete: $reply');
    }
    return DecodedAudio(
      sampleRate: sampleRate as int,
      channels: channels as int,
      frames: frames as int,
    );
  }

  Future<File> replaceAudio(
    String input,
    String audio,
    String output,
    int bitRate,
  ) async {
    final Object? reply = await _invoke(replaceAudioMethod, <String, Object?>{
      'input': input,
      'audio': audio,
      'output': output,
      'bitRate': bitRate,
    });
    if (reply is! String || reply.isEmpty) {
      throw AudioCleanException(
        'expected the written file path, got ${reply.runtimeType}',
      );
    }
    return File(reply);
  }

  Future<Object?> _invoke(String method, Map<String, Object?> arguments) async {
    try {
      return await _channel.invokeMethod<Object?>(method, arguments);
    } on PlatformException catch (error) {
      throw AudioCleanException(
        'the platform could not run $method: ${error.code}',
        error,
      );
    } on MissingPluginException catch (error) {
      throw AudioCleanException('no platform audio cleaner', error);
    }
  }

  static bool _isPositiveInt(Object? value) => value is int && value > 0;
}

final Provider<AudioCleanChannel> audioCleanChannelProvider =
    Provider<AudioCleanChannel>((Ref ref) => const AudioCleanChannel());
