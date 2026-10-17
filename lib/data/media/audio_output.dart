import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String audioOutputChannelName = 'field_notes/audio_output';
const String defaultOutputNameMethod = 'defaultOutputName';
const String openSoundSettingsMethod = 'openSoundSettings';
const String listOutputsMethod = 'listOutputs';
const String systemOutputLabel = 'System output';

@immutable
class AudioOutputDevice {
  const AudioOutputDevice({required this.id, required this.name});

  final String? id;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is AudioOutputDevice && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'AudioOutputDevice($id, $name)';
}

const AudioOutputDevice _systemOutput = AudioOutputDevice(
  id: null,
  name: systemOutputLabel,
);

AudioOutputDevice resolveAudioOutput(
  List<AudioOutputDevice> outputs,
  String? storedId,
) {
  if (storedId == null) {
    return _systemOutput;
  }
  for (final AudioOutputDevice output in outputs) {
    if (output.id == storedId) {
      return output;
    }
  }
  return _systemOutput;
}

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

  Future<List<AudioOutputDevice>> listOutputs() async {
    final Object? reply;
    try {
      reply = await _channel.invokeMethod<Object?>(listOutputsMethod);
    } on PlatformException {
      return const <AudioOutputDevice>[_systemOutput];
    } on MissingPluginException {
      return const <AudioOutputDevice>[_systemOutput];
    }
    final List<AudioOutputDevice>? reported = _reportedOutputs(reply);
    if (reported == null) {
      return const <AudioOutputDevice>[_systemOutput];
    }
    return List<AudioOutputDevice>.unmodifiable(<AudioOutputDevice>[
      _systemOutput,
      ...reported,
    ]);
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

List<AudioOutputDevice>? _reportedOutputs(Object? reply) {
  if (reply is! List<Object?>) {
    return null;
  }
  final List<AudioOutputDevice?> outputs = reply
      .map(_reportedOutput)
      .toList(growable: false);
  if (outputs.contains(null)) {
    return null;
  }
  return outputs.whereType<AudioOutputDevice>().toList(growable: false);
}

AudioOutputDevice? _reportedOutput(Object? entry) {
  if (entry is! Map<Object?, Object?>) {
    return null;
  }
  final Object? id = entry['id'];
  final Object? name = entry['name'];
  if (id is! String || id.isEmpty || name is! String || name.isEmpty) {
    return null;
  }
  return AudioOutputDevice(id: id, name: name);
}

final Provider<AudioOutput> audioOutputProvider = Provider<AudioOutput>(
  (Ref ref) => const AudioOutput(),
);

final FutureProvider<List<AudioOutputDevice>> audioOutputsProvider =
    FutureProvider<List<AudioOutputDevice>>(
      (Ref ref) => ref.watch(audioOutputProvider).listOutputs(),
    );
