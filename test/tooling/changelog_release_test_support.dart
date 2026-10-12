import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _heading = '## [1.0.0] - 2026-10-12';

const List<String> newEntries = <String>[
  'An About page in Settings shows the version of Field Notes you have, who made it and its licence.',
  'Check for updates from Settings > About, or let Field Notes check once a day by itself. Nothing installs until you choose.',
  'On macOS and Windows, an update downloads, installs and restarts Field Notes for you, with your journal and any open draft saved first.',
  'On Android, Field Notes downloads the new APK, checks it and hands it to Android to install. Copies installed from Google Play open Google Play to update.',
];

const List<String> improvedEntries = <String>[
  'Settings on macOS and Windows has a new look: a list of sections on the left, with the open section beside it in clear groups and smaller controls.',
];

const List<String> fixedEntries = <String>[
  'The glow around the voice recorder\'s orb follows your voice as you speak, instead of breathing on a fixed cycle.',
  'Recording a voice or video note keeps your phone, Mac or Windows PC awake, so the screen timeout or sleep no longer cuts a recording short.',
];

String _list(String title, List<String> items) =>
    '### $title\n\n${items.map((String item) => '- $item').join('\n')}\n';

void expectReleaseNotes(String path) {
  final List<String> lines = File(path).readAsStringSync().split('\n');
  expect(lines.where((String line) => line.startsWith('## [1.0.0]')), <String>[
    _heading,
  ]);
  final int unreleased = lines.indexOf('## [Unreleased]');
  final int release = lines.indexOf(_heading);
  expect(unreleased, greaterThanOrEqualTo(0));
  expect(unreleased, lessThan(release));

  final ProcessResult result = Process.runSync('bash', <String>[
    'tool/release/changelog_section.sh',
    '1.0.0',
    path,
  ]);
  expect(result.exitCode, 0, reason: '${result.stderr}');
  expect(
    result.stdout as String,
    '${_list('New', newEntries)}\n'
    '${_list('Improved', improvedEntries)}\n'
    '${_list('Fixed', fixedEntries)}',
  );
}
