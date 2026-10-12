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
}
