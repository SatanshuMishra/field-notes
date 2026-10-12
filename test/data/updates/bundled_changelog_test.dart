import 'dart:convert';

import 'package:field_notes/data/updates/bundled_changelog.dart';
import 'package:field_notes/data/updates/changelog_parser.dart';
import 'package:field_notes/domain/updates/updates.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

const String _changelog = '''
# Changelog

Each release has a section `## [X.Y.Z] - YYYY-MM-DD` with an optional intro paragraph and `### New`, `### Improved` and `### Fixed` lists.

## [Unreleased]

### New

- Something still to come.

## [1.2.0] - 2026-10-09

Settings has a **new** look.

### New

- An About page.

### Fixed

- A fixed bug.

## [1.1.0] - 2026-09-01

### Fixed

- An older fix.

## [1.0.0]

The first release.
''';

void _mockVersion(String version) {
  PackageInfo.setMockInitialValues(
    appName: 'Field Notes',
    packageName: 'dev.satanshumishra.field_notes',
    version: version,
    buildNumber: '3',
    buildSignature: '',
  );
}

Future<ChangelogSection?> _installedNotes(String version) async {
  _mockVersion(version);
  rootBundle.evict(bundledChangelogAsset);
  final ProviderContainer container = ProviderContainer();
  addTearDown(container.dispose);
  return container.read(installedReleaseNotesProvider.future);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    "the installed version's notes come from the bundled changelog",
    () async {
      final List<String> requested = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', (ByteData? message) async {
            final String key = utf8.decode(
              message!.buffer.asUint8List(
                message.offsetInBytes,
                message.lengthInBytes,
              ),
            );
            requested.add(key);
            if (key != 'CHANGELOG.md') {
              return null;
            }
            return ByteData.sublistView(
              Uint8List.fromList(utf8.encode(_changelog)),
            );
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMessageHandler('flutter/assets', null),
      );

      rootBundle.evict(bundledChangelogAsset);
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);
      expect(await container.read(bundledChangelogProvider.future), _changelog);
      expect(requested, contains('CHANGELOG.md'));

      expect(
        await _installedNotes('1.2.0'),
        ChangelogSection(
          notes: ReleaseNotes(
            intro: 'Settings has a new look.',
            groups: <ReleaseNoteGroup>[
              ReleaseNoteGroup(title: 'New', items: <String>['An About page.']),
              ReleaseNoteGroup(title: 'Fixed', items: <String>['A fixed bug.']),
            ],
          ),
          date: DateTime(2026, 10, 9),
        ),
      );

      final ChangelogSection? older = await _installedNotes('1.1.0');
      expect(older!.date, DateTime(2026, 9, 1));
      expect(older.notes.intro, isEmpty);
      expect(older.notes.groups, <ReleaseNoteGroup>[
        ReleaseNoteGroup(title: 'Fixed', items: <String>['An older fix.']),
      ]);

      final ChangelogSection? undated = await _installedNotes('1.0.0');
      expect(undated!.date, isNull);
      expect(undated.notes.intro, 'The first release.');

      expect(await _installedNotes('1.3.0'), isNull);
      expect(await _installedNotes('not a version'), isNull);

      expect(
        changelogSection(_changelog, AppVersion.tryParse('v1.2.0')!)?.date,
        DateTime(2026, 10, 9),
      );
      expect(changelogSection('', AppVersion.tryParse('1.2.0')!), isNull);
    },
  );
}
