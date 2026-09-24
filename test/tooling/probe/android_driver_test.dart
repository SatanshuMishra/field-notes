import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../../../tool/probe/lib/gates.dart';

const String _driver = 'tool/probe/android';

const Map<String, String> _withoutAdb = <String, String>{
  'PATH': '/usr/bin:/bin',
};

const List<String> _requiredKeys = <String>[
  'a',
  'b',
  'c',
  'd',
  'e',
  'f',
  'g',
  'h',
  'i',
  'j',
  'k',
  'l',
  'm',
  'n',
  'o',
  'p',
  'q',
  'r',
  's',
  't',
  'u',
  'v',
  'w',
  'x',
  'y',
  'z',
  '0',
  '1',
  '2',
  '3',
  '4',
  '5',
  '6',
  '7',
  '8',
  '9',
  'space',
  'enter',
  'backspace',
  'shift',
  'symbols',
  'emoji',
  'clipboard',
  'voice',
];

bool _onPath(String executable) {
  final String path = Platform.environment['PATH'] ?? '';
  return path
      .split(':')
      .where((String directory) => directory.isNotEmpty)
      .any((String directory) => File('$directory/$executable').existsSync());
}

final String? _zshSkip = _onPath('zsh') ? null : 'zsh is not installed';

List<String> _lines(Object? output) => const LineSplitter().convert('$output');

Future<ProcessResult> _zsh(List<String> arguments) =>
    Process.run('zsh', arguments, environment: _withoutAdb);

Future<ProcessResult> _library(String script) =>
    _zsh(<String>['-c', 'source $_driver/drive.sh --library; $script']);

void main() {
  test('the android driver scripts parse and list every scenario', () async {
    for (final String script in <String>['run.sh', 'drive.sh']) {
      final ProcessResult parsed = await _zsh(<String>[
        '-n',
        '$_driver/$script',
      ]);
      expect(parsed.exitCode, 0, reason: '$script: ${parsed.stderr}');
      final ProcessResult listed = await _zsh(<String>[
        '$_driver/$script',
        '--list',
      ]);
      expect(listed.exitCode, 0, reason: '$script: ${listed.stderr}');
      expect(_lines(listed.stdout), probeScenarios, reason: script);
    }
    final ProcessResult checked = await _zsh(<String>[
      '$_driver/drive.sh',
      '--check',
    ]);
    expect(checked.exitCode, 0, reason: '${checked.stderr}');
  }, skip: _zshSkip);

  test('the android overrides replace the macOS primitives', () async {
    final ProcessResult name = await _library('plat_name');
    expect(_lines(name.stdout), <String>['android']);
    final ProcessResult budget = await _library('plat_reveal_budget_ms');
    expect(_lines(budget.stdout), <String>['300']);
    final ProcessResult scales = await _library('plat_text_scales');
    expect(_lines(scales.stdout), <String>['1.0', '1.3', '2.0']);
    final ProcessResult hooks = await _library(
      'whence -w plat_ime_cases plat_image_insert_cases plat_a11y_cases',
    );
    expect(_lines(hooks.stdout), <String>[
      'plat_ime_cases: function',
      'plat_image_insert_cases: function',
      'plat_a11y_cases: function',
    ]);
    for (final String primitive in <String>[
      'plat_right_click',
      'plat_click',
      'plat_drag',
    ]) {
      final ProcessResult body = await _library('functions $primitive');
      expect(body.exitCode, 0, reason: '${body.stderr}');
      final String text = '${body.stdout}';
      expect(text, contains('adb'), reason: primitive);
      expect(text, isNot(contains('PROBE_BIN')), reason: primitive);
      expect(text, isNot(contains('/inp')), reason: primitive);
    }
  }, skip: _zshSkip);

  test('the key-map readme names every required key', () {
    final String readme = File('$_driver/keymaps/README.md').readAsStringSync();
    for (final String key in _requiredKeys) {
      expect(readme, contains('`$key`'), reason: key);
    }
    expect(readme, contains('record-keymap gboard'));
    expect(readme, contains('record-keymap samsung'));
    expect(readme, contains('"orientation": "portrait"'));
  });

  test('run.sh rejects an unknown scenario before calling adb', () async {
    final ProcessResult result = await _zsh(<String>[
      '$_driver/run.sh',
      'nope',
    ]);
    expect(result.exitCode, 2);
    expect('${result.stderr}', contains('unknown scenario nope'));
    expect('${result.stderr}', isNot(contains('adb')));
  }, skip: _zshSkip);
}
