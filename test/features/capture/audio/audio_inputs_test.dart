import 'package:field_notes/features/capture/audio/audio_inputs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';

InputDeviceLister _lister(List<InputDevice> devices) =>
    () async => devices;

List<String?> _ids(List<AudioInput> inputs) =>
    inputs.map((input) => input.id).toList();

List<String> _labels(List<AudioInput> inputs) =>
    inputs.map((input) => input.label).toList();

void main() {
  test('inputs list the system default first, then each device', () async {
    final inputs = await listAudioInputs(
      _lister(const <InputDevice>[
        InputDevice(id: 'a', label: 'MacBook Pro Microphone'),
        InputDevice(id: 'b', label: 'CORSAIR HS80 MAX'),
        InputDevice(id: 'c', label: 'USB Mic'),
      ]),
    );

    expect(_labels(inputs), <String>[
      'System default',
      'MacBook Pro Microphone',
      'CORSAIR HS80 MAX',
      'USB Mic',
    ]);
    expect(_ids(inputs), <String?>[null, 'a', 'b', 'c']);
  });

  test(
    'an empty or single device list still offers the system default',
    () async {
      final none = await listAudioInputs(_lister(const <InputDevice>[]));
      final one = await listAudioInputs(
        _lister(const <InputDevice>[InputDevice(id: 'a', label: 'Mic')]),
      );

      expect(_labels(none), <String>['System default']);
      expect(_labels(one), <String>['System default', 'Mic']);
    },
  );

  test('a broken device list falls back to the system default', () async {
    final broken = await listAudioInputs(() async => throw Exception('boom'));
    final odd = await listAudioInputs(
      _lister(const <InputDevice>[
        InputDevice(id: '', label: 'Ghost'),
        InputDevice(id: 'a', label: ''),
        InputDevice(id: 'a', label: 'Duplicate'),
      ]),
    );

    expect(_labels(broken), <String>['System default']);
    expect(_ids(odd), <String?>[null, 'a']);
    expect(_labels(odd), <String>['System default', 'a']);
  });

  test('the stored input resolves only to a listed device', () async {
    final inputs = await listAudioInputs(
      _lister(const <InputDevice>[
        InputDevice(id: 'a', label: 'First'),
        InputDevice(id: 'b', label: 'Second'),
      ]),
    );

    expect(resolveAudioInput(inputs, null).label, 'System default');
    expect(resolveAudioInput(inputs, 'b').id, 'b');
    expect(resolveAudioInput(inputs, 'z').label, 'System default');
    expect(resolveAudioInput(inputs, 'B').label, 'System default');
    expect(resolveAudioInput(inputs, 'B').id, isNull);
  });
}
