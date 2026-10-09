import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const Map<String, String> _windowsMediaPlugins = <String, String>{
  'camera_windows': '^0.3.0',
  'video_player_win': '^3.3.0',
  'just_audio_windows': '^0.2.3',
};

String _topLevelSection(String yaml, String key) {
  final List<String> lines = yaml.split('\n');
  final int start = lines.indexOf('$key:');
  expect(start, isNot(-1), reason: 'pubspec.yaml has no $key section');
  final List<String> body = <String>[];
  for (final String line in lines.skip(start + 1)) {
    if (line.isNotEmpty && !line.startsWith(' ') && !line.startsWith('#')) {
      break;
    }
    body.add(line);
  }
  return body.join('\n');
}

String _lockEntry(String lock, String package) {
  final RegExpMatch? entry = RegExp(
    '^  ${RegExp.escape(package)}:\\n((?:    .*\\n)+)',
    multiLine: true,
  ).firstMatch(lock);
  expect(entry, isNotNull, reason: 'pubspec.lock does not resolve $package');
  return entry!.group(1)!;
}

List<int> _versionParts(String version) {
  final RegExpMatch? match = RegExp(r'^(\d+)\.(\d+)\.(\d+)')
      .firstMatch(version);
  expect(match, isNotNull, reason: '$version is not a version');
  return <int>[
    for (int group = 1; group <= 3; group += 1) int.parse(match!.group(group)!),
  ];
}

bool _atLeast(String version, List<int> floor) {
  final List<int> parts = _versionParts(version);
  for (int index = 0; index < floor.length; index += 1) {
    if (parts[index] != floor[index]) {
      return parts[index] > floor[index];
    }
  }
  return true;
}

void main() {
  test('Windows has an implementation for every media plugin', () {
    final String pubspec = File('pubspec.yaml').readAsStringSync();
    final String lock = File('pubspec.lock').readAsStringSync();
    final String dependencies = _topLevelSection(pubspec, 'dependencies');

    for (final MapEntry<String, String> plugin
        in _windowsMediaPlugins.entries) {
      expect(
        RegExp(
          '^  ${RegExp.escape(plugin.key)}: '
          '${RegExp.escape(plugin.value)}\$',
          multiLine: true,
        ).hasMatch(dependencies),
        isTrue,
        reason: 'pubspec.yaml must depend on ${plugin.key} ${plugin.value}',
      );
      expect(
        _lockEntry(lock, plugin.key),
        contains('dependency: "direct main"'),
        reason: '${plugin.key} must be a direct main dependency',
      );
    }

    final RegExpMatch? resolved = RegExp(r'version: "([^"]+)"')
        .firstMatch(_lockEntry(lock, 'video_player_win'));
    expect(resolved, isNotNull, reason: 'video_player_win has no version');
    expect(
      _atLeast(resolved!.group(1)!, const <int>[3, 3, 0]),
      isTrue,
      reason:
          'video_player_win ${resolved.group(1)} predates 3.3.0, which '
          'fixes the black video under Impeller',
    );
  });
}
