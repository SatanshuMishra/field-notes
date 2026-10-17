import 'dart:io';

import 'package:audioplayers_android/audioplayers_android.dart'
    as audioplayers_android;
import 'package:audioplayers_darwin/audioplayers_darwin.dart'
    as audioplayers_darwin;
import 'package:audioplayers_windows/audioplayers_windows.dart'
    as audioplayers_windows;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:just_audio_windows/just_audio_windows.dart'
    as just_audio_windows;
import 'package:video_player_android/video_player_android.dart'
    as video_player_android;
import 'package:video_player_avfoundation/video_player_avfoundation.dart'
    as video_player_avfoundation;
import 'package:video_player_win/video_player_win.dart' as video_player_win;

const List<String> _vendoredPackages = <String>[
  'just_audio',
  'just_audio_windows',
  'video_player_avfoundation',
  'video_player_android',
  'video_player_win',
  'audioplayers_darwin',
  'audioplayers_android',
  'audioplayers_windows',
];

const List<String> _directDependencies = <String>[
  'just_audio_windows: ^0.2.3',
  'video_player_avfoundation: ^2.12.0',
  'video_player_android: ^2.12.2',
  'video_player_win: ^3.3.0',
  'audioplayers_darwin: ^6.5.0',
  'audioplayers_android: ^5.3.0',
  'audioplayers_windows: ^4.4.1',
];

const Map<String, String> _setterSources = <String, String>{
  'just_audio': 'third_party/just_audio/lib/just_audio.dart',
  'just_audio_windows':
      'third_party/just_audio_windows/lib/just_audio_windows.dart',
  'video_player_avfoundation': 'third_party/video_player_avfoundation/lib/video_player_avfoundation.dart',
  'video_player_android':
      'third_party/video_player_android/lib/video_player_android.dart',
  'video_player_win': 'third_party/video_player_win/lib/video_player_win.dart',
  'audioplayers_darwin':
      'third_party/audioplayers_darwin/lib/audioplayers_darwin.dart',
  'audioplayers_android':
      'third_party/audioplayers_android/lib/audioplayers_android.dart',
  'audioplayers_windows':
      'third_party/audioplayers_windows/lib/audioplayers_windows.dart',
};

final Map<String, Future<void> Function(String?)> _setters =
    <String, Future<void> Function(String?)>{
      'just_audio': just_audio.setPreferredOutputDevice,
      'just_audio_windows': just_audio_windows.setPreferredOutputDevice,
      'video_player_avfoundation':
          video_player_avfoundation.setPreferredOutputDevice,
      'video_player_android': video_player_android.setPreferredOutputDevice,
      'video_player_win': video_player_win.setPreferredOutputDevice,
      'audioplayers_darwin': audioplayers_darwin.setPreferredOutputDevice,
      'audioplayers_android': audioplayers_android.setPreferredOutputDevice,
      'audioplayers_windows': audioplayers_windows.setPreferredOutputDevice,
    };

String _section(String pubspec, String name) {
  final int start = pubspec.indexOf('\n$name:\n');
  expect(start, isNot(-1), reason: '$name section missing');
  final int bodyStart = start + name.length + 3;
  final RegExpMatch? next = RegExp(
    r'^\S',
    multiLine: true,
  ).firstMatch(pubspec.substring(bodyStart));
  return pubspec.substring(
    bodyStart,
    next == null ? pubspec.length : bodyStart + next.start,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the vendored players are overridden', () {
    final String pubspec = File('pubspec.yaml').readAsStringSync();
    final String overrides = _section(pubspec, 'dependency_overrides');
    for (final String package in _vendoredPackages) {
      expect(
        overrides,
        contains('  $package:\n    path: third_party/$package\n'),
        reason: '$package is not overridden to third_party/$package',
      );
    }
    final String dependencies = _section(pubspec, 'dependencies');
    for (final String dependency in _directDependencies) {
      expect(
        dependencies,
        contains('  $dependency\n'),
        reason: '$dependency is not a direct dependency',
      );
    }
    for (final String package in _vendoredPackages) {
      expect(
        Directory('third_party/$package').existsSync(),
        isTrue,
        reason: 'third_party/$package missing',
      );
      expect(
        File('third_party/$package/LICENSE').existsSync(),
        isTrue,
        reason: 'third_party/$package/LICENSE missing',
      );
    }
  });

  test('each package exposes the output setter', () async {
    for (final String package in _vendoredPackages) {
      final String source = File(_setterSources[package]!).readAsStringSync();
      expect(
        source,
        contains('Future<void> setPreferredOutputDevice(String? id)'),
        reason: '$package declares no setter',
      );
      expect(
        source,
        contains("'field_notes/output_route/$package'"),
        reason: '$package uses the wrong channel',
      );
      expect(
        source,
        contains("'setPreferredOutputDevice'"),
        reason: '$package sends the wrong method',
      );
      expect(source, contains("<String, Object?>{'id': id}"));
      expect(source, contains('on MissingPluginException'));
    }

    for (final String package in _vendoredPackages) {
      final List<MethodCall> calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            MethodChannel('field_notes/output_route/$package'),
            (MethodCall call) async {
              calls.add(call);
              return null;
            },
          );
      await _setters[package]!('speakers-uid');
      await _setters[package]!(null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            MethodChannel('field_notes/output_route/$package'),
            null,
          );
      expect(calls.map((MethodCall call) => call.method), <String>[
        'setPreferredOutputDevice',
        'setPreferredOutputDevice',
      ]);
      expect(calls[0].arguments, <String, Object?>{'id': 'speakers-uid'});
      expect(calls[1].arguments, <String, Object?>{'id': null});
    }
  });

  test('calling a setter without a native plugin is safe', () async {
    for (final String package in _vendoredPackages) {
      await _setters[package]!('speakers-uid');
    }
  });
}
