import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _machLookup =
    'com.apple.security.temporary-exception.mach-lookup.global-name';
const List<String> _sparkleServices = <String>[
  r'$(PRODUCT_BUNDLE_IDENTIFIER)-spks',
  r'$(PRODUCT_BUNDLE_IDENTIFIER)-spki',
];

final RegExp _plistEntry = RegExp(
  r'<key>([^<]+)</key>\s*(<true/>|<false/>|<string>([^<]*)</string>|<array>([\s\S]*?)</array>)',
);
final RegExp _plistString = RegExp(r'<string>([^<]*)</string>');

Map<String, Object> _plist(String path) {
  final String text = File(path).readAsStringSync();
  return <String, Object>{
    for (final RegExpMatch entry in _plistEntry.allMatches(text))
      entry.group(1)!: switch (entry.group(2)!) {
        '<true/>' => true,
        '<false/>' => false,
        final String value when value.startsWith('<string>') => entry.group(3)!,
        _ => <String>[
          for (final RegExpMatch item in _plistString.allMatches(
            entry.group(4)!,
          ))
            item.group(1)!,
        ],
      },
  };
}

String _block(String project, String id, String name) {
  final int start = project.indexOf('$id /* $name */ = {');
  expect(start, isNot(-1), reason: 'project.pbxproj has no block for $name');
  final int end = project.indexOf('\n\t\t};', start);
  return project.substring(start, end);
}

void main() {
  test('the Mac app carries Sparkle with the installer service', () {
    final List<String> podfile = File('macos/Podfile').readAsLinesSync();
    final int runnerTarget = podfile.indexOf("target 'Runner' do");
    final int postInstall = podfile.indexWhere(
      (String line) => line.startsWith('post_install'),
    );
    final List<int> sparklePods = <int>[
      for (int index = 0; index < podfile.length; index++)
        if (podfile[index].contains("pod 'Sparkle'")) index,
    ];
    expect(runnerTarget, isNot(-1));
    expect(sparklePods, hasLength(1));
    expect(podfile[sparklePods.single].trim(), "pod 'Sparkle', '2.9.6'");
    expect(sparklePods.single, greaterThan(runnerTarget));
    expect(sparklePods.single, lessThan(postInstall));
    final String podfileLock = File('macos/Podfile.lock').readAsStringSync();
    expect(podfileLock, contains('  - Sparkle (2.9.6)'));
    expect(podfileLock, contains('  - Sparkle (= 2.9.6)'));

    final Map<String, Object> info = _plist('macos/Runner/Info.plist');
    expect(
      info['SUFeedURL'],
      'https://github.com/SatanshuMishra/field-notes/releases/latest/download/appcast.xml',
    );
    expect(info['SUPublicEDKey'], r'$(FIELD_NOTES_UPDATE_PUBLIC_KEY)');
    expect(info['SUEnableInstallerLauncherService'], isTrue);
    expect(info['SUEnableAutomaticChecks'], isFalse);
    expect(info['SUAutomaticallyUpdate'], isFalse);
    expect(info.containsKey('SUEnableDownloaderService'), isFalse);
    expect(info['CFBundleIdentifier'], r'$(PRODUCT_BUNDLE_IDENTIFIER)');

    final List<File> buildSettings = <File>[
      for (final String folder in <String>[
        'macos/Runner/Configs',
        'macos/Flutter',
      ])
        ...Directory(folder)
            .listSync()
            .whereType<File>()
            .where((File file) => file.path.endsWith('.xcconfig')),
    ];
    expect(buildSettings, isNotEmpty);
    for (final File settings in buildSettings) {
      expect(
        settings.readAsStringSync(),
        isNot(contains('FIELD_NOTES_UPDATE_PUBLIC_KEY')),
        reason: settings.path,
      );
    }

    final Map<String, Map<String, Object>> entitlements =
        <String, Map<String, Object>>{
          'macos/Runner/Release.entitlements': <String, Object>{
            'com.apple.security.app-sandbox': true,
            'com.apple.security.network.client': true,
            'com.apple.security.device.camera': true,
            'com.apple.security.device.audio-input': true,
            'com.apple.security.personal-information.photos-library': true,
            'com.apple.security.files.user-selected.read-write': true,
            _machLookup: _sparkleServices,
          },
          'macos/Runner/DebugProfile.entitlements': <String, Object>{
            'com.apple.security.app-sandbox': true,
            'com.apple.security.cs.allow-jit': true,
            'com.apple.security.network.server': true,
            'com.apple.security.network.client': true,
            'com.apple.security.device.camera': true,
            'com.apple.security.device.audio-input': true,
            'com.apple.security.personal-information.photos-library': true,
            'com.apple.security.files.user-selected.read-write': true,
            _machLookup: _sparkleServices,
          },
        };
    for (final MapEntry<String, Map<String, Object>> file
        in entitlements.entries) {
      expect(_plist(file.key), file.value, reason: file.key);
    }

    final String project = File('macos/Runner.xcodeproj/project.pbxproj')
        .readAsStringSync();
    final RegExpMatch? buildFile = RegExp(
      r'(\w{24}) /\* SparkleUpdaterBridge\.swift in Sources \*/ = \{isa = PBXBuildFile; fileRef = (\w{24}) /\* SparkleUpdaterBridge\.swift \*/; \};',
    ).firstMatch(project);
    expect(buildFile, isNotNull);
    expect(
      project,
      contains(
        '${buildFile!.group(2)} /* SparkleUpdaterBridge.swift */ = '
        '{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; '
        'path = SparkleUpdaterBridge.swift; sourceTree = "<group>"; };',
      ),
    );
    final RegExpMatch? runner = RegExp(
      r'(\w{24}) /\* Runner \*/ = \{\n\t\t\tisa = PBXNativeTarget;',
    ).firstMatch(project);
    expect(runner, isNotNull);
    final String runnerBlock = _block(project, runner!.group(1)!, 'Runner');
    final RegExpMatch? sourcesPhase = RegExp(r'(\w{24}) /\* Sources \*/,')
        .firstMatch(runnerBlock);
    expect(sourcesPhase, isNotNull);
    final String sources = _block(project, sourcesPhase!.group(1)!, 'Sources');
    expect(sources, contains('isa = PBXSourcesBuildPhase;'));
    expect(
      sources,
      contains(
        '${buildFile.group(1)} /* SparkleUpdaterBridge.swift in Sources */,',
      ),
    );
    expect(sources, contains('/* MainFlutterWindow.swift in Sources */,'));
    expect(project, isNot(contains('FIELD_NOTES_UPDATE_PUBLIC_KEY')));

    final String bridge = File('macos/Runner/SparkleUpdaterBridge.swift')
        .readAsStringSync();
    expect(bridge, contains('"field_notes/updater"'));
    expect(bridge, contains('"field_notes/updater/events"'));
    expect(bridge, contains('SPUUpdater('));
    expect(
      File('macos/Runner/MainFlutterWindow.swift').readAsStringSync(),
      contains('SparkleUpdaterBridge(messenger:'),
    );
  });
}
