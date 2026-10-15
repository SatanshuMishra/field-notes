import 'dart:io';

import 'package:camera_windows/camera_windows.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const MethodChannel _audioInputChannel = MethodChannel(
  'plugins.flutter.io/camera_windows/audio_input',
);
const String _plugin = 'third_party/camera_windows';

String _read(String path) => File(path).readAsStringSync();

String _functionBody(String source, String signature) {
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
  TestWidgetsFlutterBinding.ensureInitialized();

  test("setAudioInputDevice sends the endpoint id on the vendored plugin's channel", () async {
    final List<MethodCall> calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_audioInputChannel, (MethodCall call) async {
          calls.add(call);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_audioInputChannel, null),
    );

    await CameraWindows.setAudioInputDevice('{0.0.1.00000000}.{abc}');
    await CameraWindows.setAudioInputDevice(null);

    expect(calls, hasLength(2));
    expect(calls[0].method, 'setAudioInputDevice');
    expect(calls[0].arguments, <String, Object?>{
      'endpointId': '{0.0.1.00000000}.{abc}',
    });
    expect(calls[1].method, 'setAudioInputDevice');
    expect(calls[1].arguments, <String, Object?>{'endpointId': null});
  });

  test(
    'the vendored camera_windows picks the named or default capture endpoint',
    () {
      final String controller = _read(
        '$_plugin/windows/capture_controller.cpp',
      );
      final String audioSource = _functionBody(
        controller,
        'HRESULT CaptureControllerImpl::CreateDefaultAudioCaptureSource()',
      );
      final String defaultEndpoint = _functionBody(
        controller,
        'std::wstring GetDefaultCaptureEndpointId()',
      );
      final String matches = _functionBody(
        controller,
        'bool HasAudioEndpointId(',
      );
      final String readId = _functionBody(
        controller,
        'HRESULT ReadAudioEndpointId(',
      );

      expect(controller, isNot(contains('Use first audio device')));
      expect(controller, contains('#include <mmdeviceapi.h>'));
      expect(controller, contains('#include "audio_input_preference.h"'));

      expect(
        readId,
        contains('MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_AUDCAP_ENDPOINT_ID'),
      );
      expect(audioSource, contains('ReadAudioEndpointId(devices[i]'));
      expect(audioSource, contains('devices[i]->Release();'));
      expect(matches, contains('!endpoint_id.empty()'));
      expect(
        defaultEndpoint,
        contains('CoCreateInstance(__uuidof(MMDeviceEnumerator)'),
      );
      expect(
        defaultEndpoint,
        contains('GetDefaultAudioEndpoint(eCapture, eConsole,'),
      );
      expect(defaultEndpoint, contains('device->GetId(&endpoint_id)'));

      final int named = audioSource.indexOf(
        'std::wstring audio_device_id = GetPreferredAudioEndpointId();',
      );
      final int fallbackToDefault = audioSource.indexOf(
        'audio_device_id = GetDefaultCaptureEndpointId();',
      );
      final int fallbackToFirst = audioSource.indexOf(
        'audio_device_id = endpoint_ids[0];',
      );
      expect(named, isNot(-1));
      expect(fallbackToDefault, greaterThan(named));
      expect(fallbackToFirst, greaterThan(fallbackToDefault));
      expect(
        RegExp(r'if \(!HasAudioEndpointId\(endpoint_ids, audio_device_id\)\)')
            .allMatches(audioSource),
        hasLength(2),
      );
      expect(
        audioSource,
        contains(
          'MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_AUDCAP_ENDPOINT_ID,\n'
          '            audio_device_id.c_str());',
        ),
      );

      final String plugin = _read('$_plugin/windows/camera_plugin.cpp');
      final String register = _functionBody(
        plugin,
        'void CameraPlugin::RegisterWithRegistrar(',
      );
      expect(plugin, contains('#include "audio_input_preference.h"'));
      expect(
        register,
        contains('"plugins.flutter.io/camera_windows/audio_input"'),
      );
      expect(register, contains('"setAudioInputDevice"'));
      expect(register, contains('EncodableValue("endpointId")'));
      expect(register, contains('SetPreferredAudioEndpointId(endpoint_id);'));
      expect(register, contains('result->Success();'));

      final String preferenceHeader = _read(
        '$_plugin/windows/audio_input_preference.h',
      );
      final String preference = _read(
        '$_plugin/windows/audio_input_preference.cpp',
      );
      expect(
        preferenceHeader,
        contains('std::wstring GetPreferredAudioEndpointId();'),
      );
      expect(
        preferenceHeader,
        contains(
          'void SetPreferredAudioEndpointId(const std::wstring& endpoint_id);',
        ),
      );
      expect(preference, contains('static std::wstring endpoint_id;'));

      final String cmake = _read('$_plugin/windows/CMakeLists.txt');
      final String sources = cmake.substring(
        cmake.indexOf('list(APPEND PLUGIN_SOURCES'),
        cmake.indexOf(')', cmake.indexOf('list(APPEND PLUGIN_SOURCES')),
      );
      expect(sources, contains('"audio_input_preference.h"'));
      expect(sources, contains('"audio_input_preference.cpp"'));

      final String dart = _read('$_plugin/lib/camera_windows.dart');
      expect(
        dart,
        contains('static Future<void> setAudioInputDevice(String? endpointId)'),
      );

      expect(
        RegExp(
          r'^  camera_windows:\n    path: third_party/camera_windows$',
          multiLine: true,
        ).hasMatch(_read('pubspec.yaml')),
        isTrue,
      );

      final String modifications = _read('$_plugin/LOCAL_MODIFICATIONS.md');
      expect(modifications, contains('`camera_windows`'));
      expect(modifications, contains('`0.3.0`'));
      expect(modifications, contains('## Delta'));
      expect(modifications, contains('1. Dart method'));
      expect(modifications, contains('setAudioInputDevice'));
      expect(
        modifications,
        contains('GetDefaultAudioEndpoint(eCapture, eConsole)'),
      );

      for (final String kept in <String>[
        'LICENSE',
        'AUTHORS',
        'CHANGELOG.md',
        'README.md',
        'pubspec.yaml',
        'lib',
        'pigeons',
        'windows',
      ]) {
        expect(
          FileSystemEntity.typeSync('$_plugin/$kept'),
          isNot(FileSystemEntityType.notFound),
          reason: '$kept is not vendored',
        );
      }
      expect(Directory('$_plugin/example').existsSync(), isFalse);
      expect(Directory('$_plugin/test').existsSync(), isFalse);
    },
  );
}
