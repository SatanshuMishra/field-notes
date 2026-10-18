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

const List<String> _new120 = <String>[
  'On macOS and Windows, you can pause a video recording and carry on where you left off. Keep saves it as one video.',
  'Choose which microphone Field Notes records from with the new Input button in the voice and video recorders, which also sets the input volume and shows a live level meter. On Android, video recordings use the microphone Android chooses.',
  'A new Voice page in Settings: Voice Isolation clears background noise like fans, traffic and typing from your voice when you keep a recording of 30 minutes or less, and Studio, the default, keeps your microphone as it is.',
  'On macOS and Windows, the Input panel shows where sound is playing and opens your computer\'s sound settings.',
];

const List<String> _improved120 = <String>[
  'On macOS and Windows, the recorder\'s buttons now sit below the window\'s title bar, clear of the window\'s own buttons.',
];

const List<String> _fixed120 = <String>[
  'Turning the camera off before a video recording now turns the camera off and records only your voice. Before, the camera kept recording while hidden.',
];

const List<String> _new130 = <String>[
  'Choose which speakers or headphones Field Notes plays through, and set its output volume, in Settings > Voice. On macOS and Windows you can also change the output from the recorder\'s Input panel.',
  'In the past-day pop-up on macOS and Windows, voice and video logs now open in the right-hand column. Tap a card to open it paused, or its play button to start playing, then go full screen when you want more room.',
  'Arrows in the past-day pop-up, and in the day sheet on Android, move to the day before or after without closing it.',
];

const List<String> _improved130 = <String>[
  'Background noise is now removed while you record, so a Voice Isolation recording appears as soon as you keep it, with nothing left to process.',
  'Voice Isolation now keeps a little of the room under your voice, softens hard "s" sounds, brings quiet and loud recordings to an even level, and keeps loud moments from distorting.',
  'The input level meter moves with your voice in Settings and in the recorder, including while you record.',
  'Microphone and input profile choices open as a menu under their row instead of a list that pushes the page down.',
  'On Android, recordings use a microphone source that skips the phone\'s own noise reduction and volume adjustment.',
];

const List<String> _fixed130 = <String>[
  'Voice Isolation recordings show their waveform again instead of a flat line, including ones saved before this update.',
  'The prompt in the past-day pop-up\'s empty right-hand column is now centred.',
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

  test('the release job finds the dated 1.2.0 notes in the changelog', () {
    final List<String> lines = _changelog().split('\n');
    final List<String> headings = lines
        .where((String line) => line.startsWith('## [1.2.0]'))
        .toList();
    expect(headings, <String>['## [1.2.0] - 2026-10-15']);
    final int unreleased = lines.indexOf('## [Unreleased]');
    final int release = lines.indexOf('## [1.2.0] - 2026-10-15');
    final int previous = lines.indexOf('## [1.1.0] - 2026-10-14');
    expect(unreleased, isNonNegative);
    expect(release, greaterThan(unreleased));
    expect(previous, greaterThan(release));

    final ProcessResult result = Process.runSync('bash', <String>[
      'tool/release/changelog_section.sh',
      '1.2.0',
      'CHANGELOG.md',
    ]);
    expect(result.exitCode, 0);
    expect(
      result.stdout,
      '### New\n\n'
      '${_new120.map((String entry) => '- $entry\n').join()}'
      '\n### Improved\n\n'
      '${_improved120.map((String entry) => '- $entry\n').join()}'
      '\n### Fixed\n\n'
      '${_fixed120.map((String entry) => '- $entry\n').join()}',
    );
  });

  test('Field Notes 1.2.0 finds its own release notes', () {
    final ChangelogSection? section = changelogSection(
      _changelog(),
      AppVersion.tryParse('1.2.0')!,
    );
    expect(section, isNotNull);
    expect(section!.date, DateTime(2026, 10, 15));
    expect(section.notes.intro, isEmpty);
    expect(
      section.notes.groups.map((ReleaseNoteGroup group) => group.title),
      <String>['New', 'Improved', 'Fixed'],
    );
    expect(section.notes.groups[0].items, _new120);
    expect(section.notes.groups[1].items, _improved120);
    expect(section.notes.groups[2].items, _fixed120);
  });

  test('the release job finds the dated 1.3.0 notes in the changelog', () {
    final List<String> lines = _changelog().split('\n');
    final List<String> headings = lines
        .where((String line) => line.startsWith('## [1.3.0]'))
        .toList();
    expect(headings, <String>['## [1.3.0] - 2026-10-18']);
    final int unreleased = lines.indexOf('## [Unreleased]');
    final int release = lines.indexOf('## [1.3.0] - 2026-10-18');
    final int previous = lines.indexOf('## [1.2.0] - 2026-10-15');
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
      '1.3.0',
      'CHANGELOG.md',
    ]);
    expect(result.exitCode, 0);
    expect(
      result.stdout,
      '### New\n\n'
      '${_new130.map((String entry) => '- $entry\n').join()}'
      '\n### Improved\n\n'
      '${_improved130.map((String entry) => '- $entry\n').join()}'
      '\n### Fixed\n\n'
      '${_fixed130.map((String entry) => '- $entry\n').join()}',
    );
  });

  test('Field Notes 1.3.0 finds its own release notes', () {
    final ChangelogSection? section = changelogSection(
      _changelog(),
      AppVersion.tryParse('1.3.0')!,
    );
    expect(section, isNotNull);
    expect(section!.date, DateTime(2026, 10, 18));
    expect(section.notes.intro, isEmpty);
    expect(
      section.notes.groups.map((ReleaseNoteGroup group) => group.title),
      <String>['New', 'Improved', 'Fixed'],
    );
    expect(section.notes.groups[0].items, _new130);
    expect(section.notes.groups[1].items, _improved130);
    expect(section.notes.groups[2].items, _fixed130);
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
