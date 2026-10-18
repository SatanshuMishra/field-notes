import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _kotlin =
    'android/app/src/main/kotlin/dev/satanshumishra/field_notes';

String _read(String path) {
  final File file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path is missing');
  return file.readAsStringSync();
}

String _block(String source, String signature) {
  final int start = source.indexOf(signature);
  expect(start, isNot(-1), reason: 'no $signature');
  final int open = source.indexOf('{', start);
  int depth = 0;
  for (int index = open; index < source.length; index += 1) {
    if (source[index] == '{') {
      depth += 1;
    } else if (source[index] == '}') {
      depth -= 1;
      if (depth == 0) {
        return source.substring(open, index + 1);
      }
    }
  }
  fail('$signature has no closing brace');
}

void main() {
  test('every runner answers listOutputs', () {
    final String swift = _read('macos/Runner/MainFlutterWindow.swift');
    expect(
      swift,
      contains(
        'private let audioOutputChannelName = "field_notes/audio_output"',
      ),
    );
    final String macChannel = _block(
      swift,
      'private func registerAudioOutputChannel(',
    );
    expect(macChannel, contains('name: audioOutputChannelName'));
    expect(macChannel, contains('case "listOutputs":'));
    expect(macChannel, contains('result(MainFlutterWindow.listOutputs())'));
    final String macList = _block(
      swift,
      'private static func listOutputs() -> [[String: String]]',
    );
    expect(macList, contains('kAudioHardwarePropertyDevices'));
    expect(macList, contains('AudioObjectID(kAudioObjectSystemObject)'));
    final String macEntry = _block(swift, 'private static func outputEntry(');
    expect(macEntry, contains('kAudioDevicePropertyStreams'));
    expect(macEntry, contains('kAudioObjectPropertyScopeOutput'));
    expect(macEntry, contains('streamsSize > 0'));
    expect(macEntry, contains('kAudioDevicePropertyDeviceUID'));
    expect(macEntry, contains('kAudioObjectPropertyName'));
    expect(macEntry, contains('"id": uid'));
    expect(macEntry, contains('"name": name'));

    final String windows = _read('windows/runner/system_channels.cpp');
    expect(
      windows,
      contains(
        'constexpr char kAudioOutputChannelName[] = "field_notes/audio_output";',
      ),
    );
    expect(
      windows,
      contains('constexpr char kListOutputsMethod[] = "listOutputs";'),
    );
    expect(
      windows,
      contains('audio_output_->SetMethodCallHandler(HandleAudioOutput);'),
    );
    final String windowsHandler = _block(
      windows,
      'void HandleAudioOutput(const Call& call, Result result)',
    );
    expect(
      windowsHandler,
      contains('call.method_name() == kListOutputsMethod'),
    );
    expect(
      windowsHandler,
      contains('result->Success(flutter::EncodableValue(ListOutputs()));'),
    );
    final String windowsList = _block(
      windows,
      'flutter::EncodableList ListOutputs()',
    );
    expect(
      windowsList,
      contains('EnumAudioEndpoints(eRender, DEVICE_STATE_ACTIVE,'),
    );
    expect(windowsList, contains('->GetId(&'));
    expect(windowsList, contains('CoTaskMemFree('));
    expect(windowsList, contains('FriendlyName('));
    final String windowsName = _block(
      windows,
      'std::optional<std::string> FriendlyName(IMMDevice* device)',
    );
    expect(windowsName, contains('OpenPropertyStore(STGM_READ,'));
    expect(windowsName, contains('PKEY_Device_FriendlyName'));

    final String kotlin = _read('$_kotlin/AudioOutputChannel.kt');
    expect(kotlin, contains('class AudioOutputChannel('));
    expect(kotlin, contains('const val CHANNEL = "field_notes/audio_output"'));
    expect(kotlin, contains('const val LIST_OUTPUTS = "listOutputs"'));
    final String handler = _block(kotlin, 'fun register(');
    expect(handler, contains('LIST_OUTPUTS -> result.success(listOutputs())'));
    expect(handler, contains('else -> result.notImplemented()'));
    expect(handler, isNot(contains('defaultOutputName')));
    expect(handler, isNot(contains('openSoundSettings')));
    expect(kotlin, contains('getDevices(AudioManager.GET_DEVICES_OUTPUTS)'));
    for (final String type in <String>[
      'AudioDeviceInfo.TYPE_BUILTIN_SPEAKER',
      'AudioDeviceInfo.TYPE_WIRED_HEADSET',
      'AudioDeviceInfo.TYPE_WIRED_HEADPHONES',
      'AudioDeviceInfo.TYPE_USB_DEVICE',
      'AudioDeviceInfo.TYPE_USB_HEADSET',
      'AudioDeviceInfo.TYPE_BLUETOOTH_A2DP',
      'AudioDeviceInfo.TYPE_BLE_HEADSET',
      'AudioDeviceInfo.TYPE_BLE_SPEAKER',
    ]) {
      expect(kotlin, contains(type));
    }
    expect(kotlin, contains('Build.VERSION_CODES.S'));
    final String id = _block(kotlin, 'private fun idOf(');
    expect(id, contains(r'"${device.type}:${device.productName}"'));
    expect(id, contains('device.address'));
    expect(id, contains(r'"$base:$address"'));
    expect(kotlin, contains('"Phone speaker"'));
    expect(kotlin, contains('"Wired headphones"'));
    expect(kotlin, contains('"USB audio"'));
    expect(kotlin, contains('"Bluetooth audio"'));

    final String activity = _read('$_kotlin/MainActivity.kt');
    final String engine = _block(
      activity,
      'override fun configureFlutterEngine(',
    );
    expect(
      engine,
      contains(
        'AudioOutputChannel(applicationContext)'
        '.register(flutterEngine.dartExecutor.binaryMessenger)',
      ),
    );
  });
}
