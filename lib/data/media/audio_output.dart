import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String audioOutputChannelName = 'field_notes/audio_output';
const String defaultOutputNameMethod = 'defaultOutputName';
const String openSoundSettingsMethod = 'openSoundSettings';

class AudioOutput {
  const AudioOutput([
    this._channel = const MethodChannel(audioOutputChannelName),
  ]);

  final MethodChannel _channel;

  Future<String?> defaultOutputName() async {
    final Object? reply;
    try {
      reply = await _channel.invokeMethod<Object?>(defaultOutputNameMethod);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
    if (reply is! String || reply.isEmpty) {
      return null;
    }
    return reply;
  }

  Future<void> openSoundSettings() async {
    try {
      await _channel.invokeMethod<void>(openSoundSettingsMethod);
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
  }
}

final Provider<AudioOutput> audioOutputProvider = Provider<AudioOutput>(
  (Ref ref) => const AudioOutput(),
);
