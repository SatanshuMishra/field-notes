import 'package:field_notes/domain/models/voice_peaks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String audioPeaksChannelName = 'field_notes/audio_peaks';
const String windowRmsMethod = 'windowRms';

class AudioPeaksDecodeException implements Exception {
  const AudioPeaksDecodeException(this.message);

  final String message;

  @override
  String toString() => 'AudioPeaksDecodeException: $message';
}

class AudioPeaksDecoder {
  const AudioPeaksDecoder([
    this._channel = const MethodChannel(audioPeaksChannelName),
  ]);

  final MethodChannel _channel;

  Future<List<double>> windowRms(String path) async {
    final Object? reply;
    try {
      reply = await _channel.invokeMethod<Object?>(
        windowRmsMethod,
        <String, Object?>{
          'path': path,
          'windowMs': voicePeaksWindow.inMilliseconds,
        },
      );
    } on PlatformException catch (error) {
      throw AudioPeaksDecodeException(
        'the platform could not decode $path: ${error.code}',
      );
    } on MissingPluginException {
      throw const AudioPeaksDecodeException('no platform decoder');
    }
    if (reply is! List<Object?>) {
      throw AudioPeaksDecodeException(
        'expected a list of RMS values, got ${reply.runtimeType}',
      );
    }
    final List<double> values = <double>[];
    for (final Object? value in reply) {
      if (value is! num || !value.isFinite || value < 0) {
        throw AudioPeaksDecodeException('not an RMS value: $value');
      }
      values.add(value.toDouble());
    }
    return List<double>.unmodifiable(values);
  }
}

final Provider<AudioPeaksDecoder> audioPeaksDecoderProvider =
    Provider<AudioPeaksDecoder>((Ref ref) => const AudioPeaksDecoder());
