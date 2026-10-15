import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _pluginSource =
    'third_party/camera_macos/macos/camera_macos/Sources/camera_macos/CameraMacosPlugin.swift';
const String _localModifications =
    'third_party/camera_macos/LOCAL_MODIFICATIONS.md';

String _functionBody(String source, String signature) {
  final int start = source.indexOf(signature);
  expect(start, isNot(-1), reason: '$signature is missing');
  final int open = source.indexOf('{', start + signature.length);
  int depth = 0;
  for (int index = open; index < source.length; index++) {
    final String character = source[index];
    if (character == '{') {
      depth++;
    } else if (character == '}') {
      depth--;
      if (depth == 0) {
        return source.substring(open + 1, index);
      }
    }
  }
  fail('$signature has no closing brace');
}

Iterable<String> _numberedItems(String markdown) => markdown
    .split(RegExp(r'\n(?=\d+\. )'))
    .where((String part) => RegExp(r'^\d+\. ').hasMatch(part));

void main() {
  test('the camera_macos plugin finds microphones as record does and falls back to the default', () {
    final String plugin = File(_pluginSource).readAsStringSync();
    final String initCamera = _functionBody(
      plugin,
      'func initCamera(_ arguments: Dictionary<String, Any>, _ result: @escaping FlutterResult)',
    );

    final RegExpMatch? types = RegExp(
      r'var (\w+): \[AVCaptureDevice\.DeviceType\] = \[\.builtInMicrophone, \.externalUnknown\]',
    ).firstMatch(initCamera);
    expect(
      types,
      isNotNull,
      reason:
          'the audio discovery must start from builtInMicrophone and '
          'externalUnknown',
    );
    final String deviceTypes = types!.group(1)!;
    final RegExpMatch? macOS14 = RegExp(
      r'if #available\(macOS 14\.0, \*\) \{([^}]*)\}',
    ).firstMatch(initCamera.substring(types.end));
    expect(
      macOS14,
      isNotNull,
      reason: 'the audio discovery must check for macOS 14',
    );
    expect(macOS14!.group(1), contains('$deviceTypes.append(.microphone)'));
    expect(macOS14.group(1), contains('$deviceTypes.append(.external)'));
    expect(
      initCamera,
      contains(
        'capturedAudioDevices = AVCaptureDevice.captureDevices(deviceTypes: $deviceTypes, mediaType: .audio)',
      ),
    );

    expect(
      initCamera,
      matches(
        RegExp(
          r'if let audioDeviceId: String = arguments\["audioDeviceId"\] as\? String, !audioDeviceId\.isEmpty \{\s*'
          r'micObject = capturedAudioDevices\.first\(where: \{ \$0\.uniqueID == audioDeviceId \}\) \?\? AVCaptureDevice\.default\(for: \.audio\)\s*'
          r'\} else \{\s*'
          r'micObject = AVCaptureDevice\.default\(for: \.audio\)\s*'
          r'\}',
        ),
      ),
      reason:
          'a found id records from that device, an id not found and an '
          'absent, empty or non-string id record from the system default',
    );

    final String modifications = File(_localModifications).readAsStringSync();
    expect(
      _numberedItems(modifications).where(
        (String item) =>
            item.contains('audioDeviceId') &&
            item.contains('.microphone') &&
            item.contains('.external`') &&
            item.contains('as? String') &&
            item.contains('AVCaptureDevice.default(for: .audio)'),
      ),
      isNotEmpty,
      reason:
          'LOCAL_MODIFICATIONS.md must describe the microphone change '
          'in a numbered delta',
    );
  });
}
