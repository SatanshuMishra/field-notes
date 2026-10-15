import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

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
  test('the macOS and Windows runners answer the audio output channel', () {
    final String swift = _read('macos/Runner/MainFlutterWindow.swift');

    expect(
      swift,
      contains(
        'private let audioOutputChannelName = "field_notes/audio_output"',
      ),
    );
    final int cameraRegistration = swift.indexOf(
      'self.registerCameraSettingsChannel(flutterViewController.engine.binaryMessenger)',
    );
    final int outputRegistration = swift.indexOf(
      'self.registerAudioOutputChannel(flutterViewController.engine.binaryMessenger)',
    );
    expect(cameraRegistration, isNot(-1));
    expect(outputRegistration, greaterThan(cameraRegistration));
    expect(
      swift.substring(cameraRegistration, outputRegistration).split('\n'),
      hasLength(2),
    );

    final String macChannel = _block(
      swift,
      'private func registerAudioOutputChannel(',
    );
    expect(macChannel, contains('name: audioOutputChannelName'));
    expect(macChannel, contains('case "defaultOutputName":'));
    expect(
      macChannel,
      contains('result(MainFlutterWindow.defaultOutputName())'),
    );
    expect(macChannel, contains('case "openSoundSettings":'));
    expect(macChannel, contains('result(FlutterMethodNotImplemented)'));

    final String macName = _block(
      swift,
      'private static func defaultOutputName() -> String?',
    );
    expect(macName, contains('kAudioHardwarePropertyDefaultOutputDevice'));
    expect(macName, contains('AudioObjectID(kAudioObjectSystemObject)'));
    expect(macName, contains('kAudioObjectPropertyName'));
    expect(macName, contains('return nil'));

    expect(
      swift,
      contains(
        'private let soundSettingsURL = '
        '"x-apple.systempreferences:com.apple.preference.sound"',
      ),
    );
    final String macOpen = _block(
      swift,
      'private static func openSoundSettings()',
    );
    expect(macOpen, contains('URL(string: soundSettingsURL)'));
    expect(macOpen, contains('NSWorkspace.shared.open(url)'));

    final String header = _read('windows/runner/system_channels.h');
    final String windows = _read('windows/runner/system_channels.cpp');

    expect(header, contains('audio_output_;'));
    expect(
      windows,
      contains(
        'constexpr char kAudioOutputChannelName[] = "field_notes/audio_output";',
      ),
    );
    expect(
      windows,
      contains(
        'audio_output_(ChannelNamed(messenger, kAudioOutputChannelName))',
      ),
    );
    expect(
      windows,
      contains('audio_output_->SetMethodCallHandler(HandleAudioOutput);'),
    );
    expect(windows, contains('#include <mmdeviceapi.h>'));
    expect(windows, contains('#include <functiondiscoverykeys_devpkey.h>'));

    final String windowsName = _block(
      windows,
      'std::optional<std::string> DefaultOutputName()',
    );
    expect(windowsName, contains('GetDefaultAudioEndpoint(eRender, eConsole,'));
    expect(windowsName, contains('OpenPropertyStore(STGM_READ,'));
    expect(windowsName, contains('PKEY_Device_FriendlyName'));
    expect(windowsName, contains('return std::nullopt;'));

    final String windowsHandler = _block(
      windows,
      'void HandleAudioOutput(const Call& call, Result result)',
    );
    expect(windowsHandler, contains('kDefaultOutputNameMethod'));
    expect(
      windowsHandler,
      contains(
        'if (!name.has_value()) {\n'
        '      result->Success();',
      ),
    );
    expect(windowsHandler, contains('kOpenSoundSettingsMethod'));
    expect(windowsHandler, contains('OpenSettingsPage(kSoundSettingsUri)'));
    expect(windowsHandler, contains('result->NotImplemented();'));
    expect(
      windows,
      contains('constexpr wchar_t kSoundSettingsUri[] = L"ms-settings:sound";'),
    );
    expect(
      windows,
      contains(
        'constexpr char kDefaultOutputNameMethod[] = "defaultOutputName";',
      ),
    );
    expect(
      windows,
      contains(
        'constexpr char kOpenSoundSettingsMethod[] = "openSoundSettings";',
      ),
    );

    expect(swift, isNot(contains('url_launcher')));
    expect(windows, isNot(contains('url_launcher')));
  });
}
