import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../../../tool/probe/lib/gates.dart';

const String _driver = 'tool/probe/macos';

const List<String> _helpers = <String>['inp', 'pasteboard', 'drag_files'];

const List<String> _platformFunctions = <String>[
  'plat_name',
  'plat_launch',
  'plat_kill',
  'plat_origin',
  'plat_click',
  'plat_right_click',
  'plat_drag',
  'plat_scroll',
  'plat_key',
  'plat_type',
  'plat_timed_type',
  'plat_clock_pair',
  'plat_cpu',
  'plat_cpu_format',
  'plat_rss',
  'plat_paste_image',
  'plat_paste_files',
  'plat_paste_mixed',
  'plat_drop_files',
  'plat_owner_step',
  'plat_speech_last',
  'plat_text_scales',
  'plat_set_text_scale',
  'plat_columns',
  'plat_reveal_budget_ms',
  'plat_ime_cases',
  'plat_image_insert_cases',
  'plat_a11y_cases',
];

bool _onPath(String executable) {
  final String path = Platform.environment['PATH'] ?? '';
  return path
      .split(':')
      .where((String directory) => directory.isNotEmpty)
      .any((String directory) => File('$directory/$executable').existsSync());
}

final String? _swiftSkip = !_onPath('swiftc')
    ? 'swiftc is not installed'
    : !Platform.isMacOS
    ? 'the Swift helpers need macOS'
    : null;

final String? _zshSkip = _onPath('zsh') ? null : 'zsh is not installed';

List<String> _lines(Object? output) => const LineSplitter().convert('$output');

Future<ProcessResult> _zsh(List<String> arguments) =>
    Process.run('zsh', arguments);

Future<ProcessResult> _library(String script) =>
    _zsh(<String>['-c', 'source $_driver/drive.sh --library; $script']);

Map<String, (int, int)> _mediaTable() {
  final List<String> lines = File(
    'integration_test/probe/corpus/README.md',
  ).readAsLinesSync();
  final int start = lines.indexOf('## Media');
  final Map<String, (int, int)> sizes = <String, (int, int)>{};
  for (final String line in lines.skip(start + 1)) {
    final List<String> cells = line
        .split('|')
        .map((String cell) => cell.trim())
        .where((String cell) => cell.isNotEmpty)
        .toList();
    if (cells.length == 3 && RegExp(r'^[0-9a-f]{12}$').hasMatch(cells[0])) {
      sizes[cells[0]] = (int.parse(cells[1]), int.parse(cells[2]));
    }
  }
  return sizes;
}

void main() {
  test(
    'the swift helpers typecheck',
    () async {
      for (final String helper in _helpers) {
        final ProcessResult result = await Process.run('swiftc', <String>[
          '-typecheck',
          '$_driver/$helper.swift',
        ]);
        expect(result.exitCode, 0, reason: '$helper: ${result.stderr}');
      }
    },
    skip: _swiftSkip,
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test('the driver scripts parse and list every scenario', () async {
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

  test(
    'each built helper refuses to run without arguments',
    () async {
      final Directory directory = Directory.systemTemp.createTempSync(
        'probe_helpers',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      for (final String helper in _helpers) {
        final String binary = '${directory.path}/$helper';
        final ProcessResult built = await Process.run('swiftc', <String>[
          '-O',
          '$_driver/$helper.swift',
          '-o',
          binary,
        ]);
        expect(built.exitCode, 0, reason: '$helper: ${built.stderr}');
        final ProcessResult run = await Process.run(binary, <String>[]);
        expect(run.exitCode, 2, reason: helper);
        expect('${run.stderr}', startsWith('usage:'), reason: helper);
        expect('${run.stdout}', isEmpty, reason: helper);
      }
    },
    skip: _swiftSkip,
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test('the corpus helpers read the committed notes and tables', () async {
    final Directory directory = Directory.systemTemp.createTempSync(
      'probe_corpus',
    );
    addTearDown(() => directory.deleteSync(recursive: true));
    final String copy = '${directory.path}/c500-p0.md';
    final ProcessResult copied = await _library('corpus_note c500-p0 $copy');
    expect(copied.exitCode, 0, reason: '${copied.stderr}');
    expect(
      File(copy).readAsBytesSync(),
      File('integration_test/probe/corpus/c500-p0.md').readAsBytesSync(),
    );

    final ProcessResult ids = await _library('corpus_ids');
    expect(_lines(ids.stdout), <String>[
      'c500-p0',
      'c500-p4',
      'c500-p8',
      'c6000-p0',
      'c6000-p4',
      'c6000-p8',
      'c6000-p24',
      'c20000-p0',
      'c20000-p4',
      'c20000-p8',
      'c20000-p24',
      'c50000-p0',
      'c50000-p4',
      'c50000-p8',
      'c50000-p24',
    ]);

    final ProcessResult media = await _library('corpus_media c500-p4');
    expect(media.exitCode, 0, reason: '${media.stderr}');
    final String note = File(
      'integration_test/probe/corpus/c500-p4.md',
    ).readAsStringSync();
    final Map<String, (int, int)> table = _mediaTable();
    final List<String> entries = '${media.stdout}'.trim().split(',');
    expect(entries, isNotEmpty);
    for (final String entry in entries) {
      final List<String> parts = entry.split(':');
      expect(parts, hasLength(3), reason: entry);
      expect(note, contains('photo/${parts[0]}'), reason: entry);
      expect(table[parts[0]], (int.parse(parts[1]), int.parse(parts[2])));
    }
    expect(
      entries.toSet(),
      hasLength(
        RegExp(r'photo/([0-9a-f]{12})')
            .allMatches(note)
            .map((RegExpMatch match) => match.group(1))
            .toSet()
            .length,
      ),
    );

    final ProcessResult unknown = await _library(
      'corpus_note nope ${directory.path}/nope.md',
    );
    expect(unknown.exitCode, 2);
  }, skip: _zshSkip);

  test('the library defines every platform function and hook', () async {
    final ProcessResult found = await _library(
      'whence -w ${_platformFunctions.join(' ')}',
    );
    expect(found.exitCode, 0, reason: '${found.stderr}');
    expect(_lines(found.stdout), <String>[
      for (final String name in _platformFunctions) '$name: function',
    ]);
    final ProcessResult budget = await _library('plat_reveal_budget_ms');
    expect(_lines(budget.stdout), <String>['150']);
    final ProcessResult name = await _library('plat_name');
    expect(_lines(name.stdout), <String>['macos']);
  }, skip: _zshSkip);

  test('run.sh rejects an unknown scenario before building', () async {
    final ProcessResult result = await _zsh(<String>[
      '$_driver/run.sh',
      'nope',
    ]);
    expect(result.exitCode, 2);
    expect('${result.stderr}', contains('unknown scenario nope'));
    expect('${result.stdout}', isEmpty);
  }, skip: _zshSkip);
}
