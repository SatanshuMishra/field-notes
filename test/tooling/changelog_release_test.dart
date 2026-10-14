import 'dart:io';

import 'package:field_notes/data/updates/changelog_parser.dart';
import 'package:field_notes/domain/updates/updates.dart';
import 'package:flutter_test/flutter_test.dart';

import 'changelog_release_test_support.dart';

const String _laterEntries =
    '## [Unreleased]\n'
    '\n'
    '### New\n'
    '\n'
    '- A later change lands here.\n'
    '\n'
    '## [1.0.1] - 2026-11-01\n'
    '\n'
    '### Fixed\n'
    '\n'
    '- A later fix lands here.\n';

const String _playBuildEntry =
    '- Field Notes from Google Play leaves out sync, so it needs no permission to upload in the background. Sync stays in the version from GitHub.';

const List<String> _entries102 = <String>[
  'On Windows, Field Notes no longer closes unexpectedly while the Meadow is showing, in onboarding or on the Meadow page.',
  'On Windows, the Meadow page opens much faster, and changing the time of day or switching to full screen no longer makes it stutter or freeze.',
  'On Windows, the Meadow animation in onboarding plays smoothly instead of stuttering.',
];

const List<String> _improved110 = <String>[
  'A short countdown before recording starts.',
  'A new live visualiser while you record.',
  'Voice waveforms now show the shape of your recording.',
];

const List<String> _fixed110 = <String>[
  'On Windows, Field Notes no longer closes when you switch back to it while reminders are on.',
  'Settings now use the same background colours as the rest of the app.',
  'A voice note in a past day keeps playing when you move the pointer away from it.',
  'The Restarting Field Notes screen no longer shows a yellow underline under its text.',
];

const String _plainEnglishRule =
    'Write the entries in plain English for the people who use Field Notes: say clearly what they will notice, and leave out technical detail such as frame rates, graphics memory figures or the names of the app\'s internal parts.';

String _changelog() => File('CHANGELOG.md').readAsStringSync();

void main() {
  test('the release job finds the dated 1.0.0 notes in the changelog', () {
    expectReleaseNotes('CHANGELOG.md');
  });

  test('Field Notes 1.0.0 finds its own release notes', () {
    final ChangelogSection? section = changelogSection(
      _changelog(),
      AppVersion.tryParse('1.0.0')!,
    );
    expect(section, isNotNull);
    expect(section!.date, DateTime(2026, 10, 12));
    expect(section.notes.intro, isEmpty);
    expect(
      section.notes.groups.map((ReleaseNoteGroup group) => group.title),
      <String>['New', 'Improved', 'Fixed'],
    );
    expect(section.notes.groups[0].items, newEntries);
    expect(section.notes.groups[1].items, improvedEntries);
    expect(section.notes.groups[2].items, fixedEntries);
  });

  test('a later entry under Unreleased and a later release keep the 1.0.0 notes check passing', () {
    final Directory folder = Directory.systemTemp.createTempSync(
      'changelog_release_test',
    );
    addTearDown(() => folder.deleteSync(recursive: true));
    final String changelog = _changelog();
    expect(changelog, contains('## [Unreleased]\n'));
    final File later = File('${folder.path}/CHANGELOG.md')
      ..writeAsStringSync(
        changelog.replaceFirst('## [Unreleased]\n', _laterEntries),
      );
    expect(later.readAsStringSync(), contains('- A later change lands here.'));

    expectReleaseNotes(later.path);
  });

  test('the release job finds the dated 1.0.1 notes in the changelog', () {
    final List<String> lines = _changelog().split('\n');
    final List<String> headings = lines
        .where((String line) => line.startsWith('## [1.0.1]'))
        .toList();
    expect(headings, <String>['## [1.0.1] - 2026-10-12']);
    final int unreleased = lines.indexOf('## [Unreleased]');
    final int release = lines.indexOf('## [1.0.1] - 2026-10-12');
    final int previous = lines.indexOf('## [1.0.0] - 2026-10-12');
    expect(unreleased, isNonNegative);
    expect(release, greaterThan(unreleased));
    expect(previous, greaterThan(release));

    final ProcessResult result = Process.runSync('bash', <String>[
      'tool/release/changelog_section.sh',
      '1.0.1',
      'CHANGELOG.md',
    ]);
    expect(result.exitCode, 0);
    expect(result.stdout, '### Improved\n\n$_playBuildEntry\n');
  });

  test('Field Notes 1.0.1 finds its own release notes', () {
    final ChangelogSection? section = changelogSection(
      _changelog(),
      AppVersion.tryParse('1.0.1')!,
    );
    expect(section, isNotNull);
    expect(section!.date, DateTime(2026, 10, 12));
    expect(section.notes.intro, isEmpty);
    expect(
      section.notes.groups.map((ReleaseNoteGroup group) => group.title),
      <String>['Improved'],
    );
    expect(section.notes.groups[0].items, <String>[
      _playBuildEntry.substring(2),
    ]);
  });

  test('the release job finds the dated 1.0.2 notes in the changelog', () {
    final List<String> lines = _changelog().split('\n');
    final List<String> headings = lines
        .where((String line) => line.startsWith('## [1.0.2]'))
        .toList();
    expect(headings, <String>['## [1.0.2] - 2026-10-13']);
    final int unreleased = lines.indexOf('## [Unreleased]');
    final int release = lines.indexOf('## [1.0.2] - 2026-10-13');
    final int previous = lines.indexOf('## [1.0.1] - 2026-10-12');
    expect(unreleased, isNonNegative);
    expect(release, greaterThan(unreleased));
    expect(previous, greaterThan(release));

    final ProcessResult result = Process.runSync('bash', <String>[
      'tool/release/changelog_section.sh',
      '1.0.2',
      'CHANGELOG.md',
    ]);
    expect(result.exitCode, 0);
    expect(
      result.stdout,
      '### Fixed\n\n${_entries102.map((String entry) => '- $entry\n').join()}',
    );
  });

  test('Field Notes 1.0.2 finds its own release notes', () {
    final ChangelogSection? section = changelogSection(
      _changelog(),
      AppVersion.tryParse('1.0.2')!,
    );
    expect(section, isNotNull);
    expect(section!.date, DateTime(2026, 10, 13));
    expect(section.notes.intro, isEmpty);
    expect(
      section.notes.groups.map((ReleaseNoteGroup group) => group.title),
      <String>['Fixed'],
    );
    expect(section.notes.groups[0].items, _entries102);
  });

  test('the release job finds the dated 1.1.0 notes in the changelog', () {
    final List<String> lines = _changelog().split('\n');
    final List<String> headings = lines
        .where((String line) => line.startsWith('## [1.1.0]'))
        .toList();
    expect(headings, <String>['## [1.1.0] - 2026-10-14']);
    final int unreleased = lines.indexOf('## [Unreleased]');
    final int release = lines.indexOf('## [1.1.0] - 2026-10-14');
    final int previous = lines.indexOf('## [1.0.2] - 2026-10-13');
    expect(unreleased, isNonNegative);
    expect(release, greaterThan(unreleased));
    expect(previous, greaterThan(release));
    expect(
      lines
          .sublist(unreleased + 1, release)
          .every((String line) => line.isEmpty),
      isTrue,
    );

    final ProcessResult result = Process.runSync('bash', <String>[
      'tool/release/changelog_section.sh',
      '1.1.0',
      'CHANGELOG.md',
    ]);
    expect(result.exitCode, 0);
    expect(
      result.stdout,
      '### Improved\n\n'
      '${_improved110.map((String entry) => '- $entry\n').join()}'
      '\n### Fixed\n\n'
      '${_fixed110.map((String entry) => '- $entry\n').join()}',
    );
  });

  test('Field Notes 1.1.0 finds its own release notes', () {
    final ChangelogSection? section = changelogSection(
      _changelog(),
      AppVersion.tryParse('1.1.0')!,
    );
    expect(section, isNotNull);
    expect(section!.date, DateTime(2026, 10, 14));
    expect(section.notes.intro, isEmpty);
    expect(
      section.notes.groups.map((ReleaseNoteGroup group) => group.title),
      <String>['Improved', 'Fixed'],
    );
    expect(section.notes.groups[0].items, _improved110);
    expect(section.notes.groups[1].items, _fixed110);
  });

  test('the changelog asks for entries in plain English for the people who use Field Notes', () {
    final List<String> lines = _changelog().split('\n');
    expect(lines[0], '# Changelog');
    expect(lines[2], startsWith('Each release has a section'));
    expect(lines[3], isEmpty);
    expect(lines[4], _plainEnglishRule);
    expect(lines[5], isEmpty);
    expect(lines[6], '## [Unreleased]');
  });
}
