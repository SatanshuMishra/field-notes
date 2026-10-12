import 'dart:convert';

import 'package:field_notes/domain/updates/updates.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

const String releasesPage =
    'https://github.com/SatanshuMishra/field-notes/releases';

ReleaseAsset sampleAsset(String tag, String name, int size) => ReleaseAsset(
  name: name,
  url: Uri.parse('$releasesPage/download/$tag/$name'),
  size: size,
);

ReleaseInfo sampleRelease({
  String tag = 'v1.4.0',
  DateTime? publishedAt,
  ReleaseNotes? notes,
  List<ReleaseAsset>? assets,
}) {
  final String fileVersion = tag.startsWith('v') ? tag.substring(1) : tag;
  return ReleaseInfo(
    version: AppVersion.tryParse(tag)!,
    tag: tag,
    publishedAt: publishedAt ?? DateTime.utc(2026, 10, 9, 18, 30, 5, 123, 456),
    notes:
        notes ??
        ReleaseNotes(
          intro: 'A calmer Settings page and updates from inside the app.',
          groups: <ReleaseNoteGroup>[
            ReleaseNoteGroup(
              title: 'Added',
              items: <String>['An About page', 'Check for updates'],
            ),
            ReleaseNoteGroup(
              title: 'Fixed',
              items: <String>['The voice level follows the microphone'],
            ),
          ],
        ),
    pageUrl: Uri.parse('$releasesPage/tag/$tag'),
    assets:
        assets ??
        <ReleaseAsset>[
          sampleAsset(tag, 'field-notes-$fileVersion-macos.dmg', 48211337),
          sampleAsset(
            tag,
            'field-notes-$fileVersion-windows-x64-setup.exe',
            39102211,
          ),
          sampleAsset(tag, 'field-notes-$fileVersion-android.apk', 61022019),
          sampleAsset(tag, releaseSumsName, 391),
          sampleAsset(tag, releaseSignatureName, 89),
          sampleAsset(tag, 'appcast.xml', 1204),
        ],
  );
}

Map<String, Object?> validJson() =>
    jsonDecode(jsonEncode(sampleRelease().toJson())) as Map<String, Object?>;

Map<String, Object?> withField(String key, Object? value) => <String, Object?>{
  ...validJson(),
  key: value,
};

Map<String, Object?> withoutField(String key) => <String, Object?>{
  for (final MapEntry<String, Object?> entry in validJson().entries)
    if (entry.key != key) entry.key: entry.value,
};

Map<String, Object?> withAsset(Map<String, Object?> asset) =>
    withField('assets', <Object?>[asset]);

Map<String, Object?> withGroups(List<Object?> groups) =>
    withField('notes', <String, Object?>{'intro': '', 'groups': groups});

void main() {
  test('toJson and fromJson round-trip every field', () {
    final ReleaseInfo release = sampleRelease(tag: 'v2.0.0-rc.1');

    final Object? stored = jsonDecode(jsonEncode(release.toJson()));
    final ReleaseInfo? restored = ReleaseInfo.fromJson(stored);

    expect(restored, isNotNull);
    expect(restored, release);
    expect(restored!.hashCode, release.hashCode);
    expect(restored.version, release.version);
    expect(restored.tag, 'v2.0.0-rc.1');
    expect(
      restored.publishedAt,
      DateTime.utc(2026, 10, 9, 18, 30, 5, 123, 456),
    );
    expect(restored.publishedAt.isUtc, isTrue);
    expect(restored.notes, release.notes);
    expect(restored.pageUrl, release.pageUrl);
    expect(restored.assets, release.assets);
    expect(
      (stored! as Map<String, Object?>)['publishedAt'],
      '2026-10-09T18:30:05.123456Z',
    );

    final ReleaseInfo bare = sampleRelease(
      notes: ReleaseNotes.empty,
      assets: const <ReleaseAsset>[],
    );
    final ReleaseInfo? bareRestored = ReleaseInfo.fromJson(
      jsonDecode(jsonEncode(bare.toJson())),
    );
    expect(bareRestored, bare);
    expect(bareRestored!.notes.isEmpty, isTrue);
    expect(bareRestored.assets, isEmpty);
  });

  test('publishedAt is kept in UTC', () {
    final DateTime local = DateTime(2026, 10, 9, 12, 30);
    final ReleaseInfo release = sampleRelease(publishedAt: local);

    expect(release.publishedAt.isUtc, isTrue);
    expect(release.publishedAt.isAtSameMomentAs(local), isTrue);
    expect(release.toJson()['publishedAt'], endsWith('Z'));
    expect(
      ReleaseInfo.fromJson(jsonDecode(jsonEncode(release.toJson()))),
      release,
    );
    expect(
      ReleaseInfo.fromJson(
        withField('publishedAt', '2026-10-09T12:30:05-06:00'),
      )!.publishedAt,
      DateTime.utc(2026, 10, 9, 18, 30, 5),
    );
  });

  test('fromJson refuses anything malformed', () {
    expect(ReleaseInfo.fromJson(validJson()), sampleRelease());

    final Map<String, Object?> cases = <String, Object?>{
      'null': null,
      'a string': 'v1.4.0',
      'a list': <Object?>[],
      'an empty map': <String, Object?>{},
      for (final String key in validJson().keys)
        'without $key': withoutField(key),
      'version latest': withField('version', 'latest'),
      'version 1.2': withField('version', '1.2'),
      'version number': withField('version', 140),
      'tag empty': withField('tag', ''),
      'tag number': withField('tag', 140),
      'publishedAt text': withField('publishedAt', 'yesterday'),
      'publishedAt number': withField('publishedAt', 1760034605),
      'pageUrl relative': withField('pageUrl', 'releases/tag/v1.4.0'),
      'pageUrl number': withField('pageUrl', 7),
      'notes text': withField('notes', 'Added an About page'),
      'notes without intro': withField('notes', <String, Object?>{
        'groups': <Object?>[],
      }),
      'notes intro number': withField('notes', <String, Object?>{
        'intro': 1,
        'groups': <Object?>[],
      }),
      'notes groups text': withField('notes', <String, Object?>{
        'intro': '',
        'groups': 'Added',
      }),
      'group text': withGroups(<Object?>['Added']),
      'group without title': withGroups(<Object?>[
        <String, Object?>{'items': <Object?>[]},
      ]),
      'group without items': withGroups(<Object?>[
        <String, Object?>{'title': 'Added'},
      ]),
      'group item number': withGroups(<Object?>[
        <String, Object?>{
          'title': 'Added',
          'items': <Object?>['An About page', 3],
        },
      ]),
      'assets map': withField('assets', <String, Object?>{}),
      'asset text': withField('assets', <Object?>['field-notes.dmg']),
      'asset name empty': withAsset(<String, Object?>{
        'name': '',
        'url': '$releasesPage/download/v1.4.0/a.dmg',
        'size': 1,
      }),
      'asset name missing': withAsset(<String, Object?>{
        'url': '$releasesPage/download/v1.4.0/a.dmg',
        'size': 1,
      }),
      'asset url relative': withAsset(<String, Object?>{
        'name': 'a.dmg',
        'url': 'download/v1.4.0/a.dmg',
        'size': 1,
      }),
      'asset size negative': withAsset(<String, Object?>{
        'name': 'a.dmg',
        'url': '$releasesPage/download/v1.4.0/a.dmg',
        'size': -1,
      }),
      'asset size fractional': withAsset(<String, Object?>{
        'name': 'a.dmg',
        'url': '$releasesPage/download/v1.4.0/a.dmg',
        'size': 1.5,
      }),
      'asset size text': withAsset(<String, Object?>{
        'name': 'a.dmg',
        'url': '$releasesPage/download/v1.4.0/a.dmg',
        'size': '12',
      }),
    };
    for (final MapEntry<String, Object?> entry in cases.entries) {
      expect(ReleaseInfo.fromJson(entry.value), isNull, reason: entry.key);
    }
  });

  test('asset finds a release file by name', () {
    final ReleaseInfo release = sampleRelease();

    expect(
      release.asset(releaseSumsName),
      sampleAsset('v1.4.0', 'SHA256SUMS.txt', 391),
    );
    expect(
      release.asset(releaseSignatureName),
      sampleAsset('v1.4.0', 'SHA256SUMS.txt.sig', 89),
    );
    expect(release.asset('field-notes-1.3.0-macos.dmg'), isNull);
    expect(sampleRelease(assets: const <ReleaseAsset>[]).asset('a'), isNull);
  });

  test('platform asset names follow the release tag', () {
    final ReleaseInfo release = sampleRelease();

    expect(releaseFileVersion(release), '1.4.0');
    expect(releaseFileVersion(sampleRelease(tag: '1.4.0')), '1.4.0');
    expect(releaseFileVersion(sampleRelease(tag: 'v2.0.0-rc.1')), '2.0.0-rc.1');
    expect(
      platformAssetName(TargetPlatform.macOS, release),
      'field-notes-1.4.0-macos.dmg',
    );
    expect(
      platformAssetName(TargetPlatform.windows, release),
      'field-notes-1.4.0-windows-x64-setup.exe',
    );
    expect(
      platformAssetName(TargetPlatform.android, release),
      'field-notes-1.4.0-android.apk',
    );
    expect(platformAssetName(TargetPlatform.iOS, release), isNull);
    expect(platformAssetName(TargetPlatform.linux, release), isNull);
    expect(platformAssetName(TargetPlatform.fuchsia, release), isNull);
    for (final TargetPlatform platform in <TargetPlatform>[
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.android,
    ]) {
      expect(
        release.asset(platformAssetName(platform, release)!),
        isNotNull,
        reason: '$platform',
      );
    }
    expect(releaseSumsName, 'SHA256SUMS.txt');
    expect(releaseSignatureName, 'SHA256SUMS.txt.sig');
  });

  test('release notes report when they are empty', () {
    expect(ReleaseNotes.empty.isEmpty, isTrue);
    expect(ReleaseNotes.empty.intro, '');
    expect(ReleaseNotes.empty.groups, isEmpty);
    expect(
      ReleaseNotes(intro: '', groups: const <ReleaseNoteGroup>[]),
      ReleaseNotes.empty,
    );
    expect(
      ReleaseNotes(intro: '', groups: const <ReleaseNoteGroup>[]).isEmpty,
      isTrue,
    );
    expect(
      ReleaseNotes(
        intro: 'Small fixes.',
        groups: const <ReleaseNoteGroup>[],
      ).isEmpty,
      isFalse,
    );
    expect(
      ReleaseNotes(
        intro: '',
        groups: <ReleaseNoteGroup>[
          ReleaseNoteGroup(title: 'Fixed', items: <String>['Sync']),
        ],
      ).isEmpty,
      isFalse,
    );
  });

  test('release values cannot change and compare by value', () {
    final List<String> items = <String>['An About page'];
    final List<ReleaseNoteGroup> groups = <ReleaseNoteGroup>[
      ReleaseNoteGroup(title: 'Added', items: items),
    ];
    final List<ReleaseAsset> assets = <ReleaseAsset>[
      sampleAsset('v1.4.0', releaseSumsName, 391),
    ];
    final ReleaseNotes notes = ReleaseNotes(intro: 'Intro', groups: groups);
    final ReleaseInfo release = sampleRelease(notes: notes, assets: assets);
    items.add('Later');
    groups.add(ReleaseNoteGroup(title: 'Fixed', items: <String>[]));
    assets.add(sampleAsset('v1.4.0', releaseSignatureName, 89));

    expect(release.notes.groups, hasLength(1));
    expect(release.notes.groups.single.items, <String>['An About page']);
    expect(release.assets, hasLength(1));
    expect(() => release.assets.add(assets.last), throwsUnsupportedError);
    expect(() => release.notes.groups.clear(), throwsUnsupportedError);
    expect(
      () => release.notes.groups.single.items.add('x'),
      throwsUnsupportedError,
    );

    expect(sampleRelease(), sampleRelease());
    expect(sampleRelease().hashCode, sampleRelease().hashCode);
    expect(sampleRelease(), isNot(sampleRelease(tag: 'v1.4.1')));
    expect(
      sampleRelease(),
      isNot(sampleRelease(publishedAt: DateTime.utc(2026, 10, 10))),
    );
    expect(sampleRelease(), isNot(sampleRelease(notes: ReleaseNotes.empty)));
    expect(
      sampleRelease(),
      isNot(sampleRelease(assets: const <ReleaseAsset>[])),
    );
  });

  test('lookups, install events and update statuses compare by value', () {
    final ReleaseInfo release = sampleRelease();
    final DateTime checkedAt = DateTime.utc(2026, 10, 11, 9, 14);

    expect(ReleaseFound(release), ReleaseFound(sampleRelease()));
    expect(
      ReleaseFound(release).hashCode,
      ReleaseFound(sampleRelease()).hashCode,
    );
    expect(
      ReleaseFound(release),
      isNot(ReleaseFound(sampleRelease(tag: 'v1.4.1'))),
    );
    expect(const NoRelease(), const NoRelease());
    expect(LookupRateLimited(checkedAt), LookupRateLimited(checkedAt));
    expect(
      const LookupFailed(LookupFailure.offline),
      isNot(const LookupFailed(LookupFailure.badResponse)),
    );

    expect(
      const InstallDownloading(10, 100),
      const InstallDownloading(10, 100),
    );
    expect(
      const InstallDownloading(10, 100),
      isNot(const InstallDownloading(10, null)),
    );
    expect(const InstallVerifying(), isNot(const InstallRestarting()));
    expect(const InstallHandedOff(), const InstallHandedOff());
    expect(
      const InstallFailed(InstallFailure.verification),
      isNot(const InstallFailed(InstallFailure.network)),
    );

    expect(UpdateIdle(null), isNot(UpdateChecking(null)));
    expect(UpdateCurrent(checkedAt), UpdateCurrent(checkedAt));
    expect(
      UpdateAvailable(release, checkedAt),
      UpdateAvailable(sampleRelease(), checkedAt),
    );
    expect(
      UpdateAvailable(release, checkedAt),
      isNot(
        UpdateAvailable(
          release,
          checkedAt,
          lastFailure: InstallFailure.notReady,
        ),
      ),
    );
    expect(UpdateDownloading(release, 0.5), UpdateDownloading(release, 0.5));
    expect(
      UpdateDownloading(release, null),
      isNot(UpdateDownloading(release, 0)),
    );
    expect(() => UpdateDownloading(release, 1.5), throwsAssertionError);
    expect(UpdateRestarting(release), UpdateRestarting(sampleRelease()));
    expect(
      UpdateCheckFailed(checkedAt, null, checkedAt),
      UpdateCheckFailed(checkedAt, null, checkedAt),
    );
    expect(
      UpdateCheckFailed(null, LookupFailure.offline, null),
      isNot(UpdateCheckFailed(null, LookupFailure.badResponse, null)),
    );
  });
}
