import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';

const String systemDefaultInputLabel = 'System default';

typedef InputDeviceLister = Future<List<InputDevice>> Function();

class AudioInput {
  const AudioInput({required this.id, required this.label});

  final String? id;
  final String label;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioInput && other.id == id && other.label == label;

  @override
  int get hashCode => Object.hash(id, label);

  @override
  String toString() => 'AudioInput($id, $label)';
}

const AudioInput _systemDefault = AudioInput(
  id: null,
  label: systemDefaultInputLabel,
);

Future<List<AudioInput>> listAudioInputs(InputDeviceLister lister) async {
  final List<InputDevice> devices;
  try {
    devices = await lister();
  } catch (_) {
    return const <AudioInput>[_systemDefault];
  }
  final seen = <String>{};
  final inputs = <AudioInput>[_systemDefault];
  for (final device in devices) {
    if (device.id.isEmpty || !seen.add(device.id)) {
      continue;
    }
    inputs.add(
      AudioInput(
        id: device.id,
        label: device.label.isEmpty ? device.id : device.label,
      ),
    );
  }
  return inputs;
}

AudioInput resolveAudioInput(List<AudioInput> inputs, String? storedId) {
  if (storedId != null) {
    for (final input in inputs) {
      if (input.id == storedId) {
        return input;
      }
    }
  }
  return _systemDefault;
}

final audioInputListerProvider = Provider<InputDeviceLister>((ref) {
  return () async {
    final recorder = AudioRecorder();
    try {
      return await recorder.listInputDevices();
    } finally {
      await recorder.dispose();
    }
  };
});

final selectedAudioInputProvider = FutureProvider<AudioInput>((ref) async {
  final settings = await ref.watch(appSettingsProvider.future);
  final inputs = await listAudioInputs(ref.watch(audioInputListerProvider));
  return resolveAudioInput(inputs, settings.audioInputId);
});
