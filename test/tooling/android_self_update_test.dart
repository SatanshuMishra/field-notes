import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _app = 'android/app';
const String _mainManifest = '$_app/src/main/AndroidManifest.xml';
const String _selfUpdateManifest = '$_app/src/selfUpdate/AndroidManifest.xml';
const String _kotlinPackage = 'kotlin/dev/satanshumishra/field_notes';
const String _mainKotlin = '$_app/src/main/$_kotlinPackage';
const String _selfUpdateKotlin = '$_app/src/selfUpdate/$_kotlinPackage';
const String _storeKotlin = '$_app/src/store/$_kotlinPackage';
const String _gradle = '$_app/build.gradle.kts';
const String _permission = 'android.permission.REQUEST_INSTALL_PACKAGES';
const String _channelName = '"field_notes/app_update"';
const List<String> _installerMarks = <String>[
  'PackageInstaller',
  'REQUEST_INSTALL_PACKAGES',
  'UpdateReplacedReceiver',
];

String _read(String path) {
  final File file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path is missing');
  return file.readAsStringSync();
}

List<File> _sources(String path) {
  final Directory directory = Directory(path);
  expect(directory.existsSync(), isTrue, reason: '$path is missing');
  return directory
      .listSync(recursive: true)
      .whereType<File>()
      .toList(growable: false);
}

String _block(String text, int open) {
  expect(text[open], '{', reason: 'a block must start at an opening brace');
  int depth = 0;
  for (int index = open; index < text.length; index++) {
    if (text[index] == '{') {
      depth++;
    } else if (text[index] == '}') {
      depth--;
      if (depth == 0) {
        return text.substring(open + 1, index);
      }
    }
  }
  fail('the block at $open never closes');
}

String _constructor(String source) {
  final RegExpMatch? match = RegExp(r'class AppUpdateChannel\(([^)]*)\)')
      .firstMatch(source);
  expect(match, isNotNull, reason: 'AppUpdateChannel must be a class');
  final String parameter = match!.group(1)!;
  return parameter.substring(parameter.lastIndexOf(':') + 1).trim();
}

void main() {
  test('only the GitHub APK can install its own updates', () {
    final String mainManifest = _read(_mainManifest);
    expect(mainManifest, isNot(contains(_permission)));
    expect(mainManifest, isNot(contains('UpdateReplacedReceiver')));
    for (final File source in _sources(
      '$_app/src/main',
    ).where((File file) => RegExp(r'\.(kt|java|xml)$').hasMatch(file.path))) {
      final String text = source.readAsStringSync();
      for (final String mark in _installerMarks) {
        expect(text, isNot(contains(mark)), reason: '${source.path}: $mark');
      }
    }
    expect(File('$_mainKotlin/AppUpdateChannel.kt').existsSync(), isFalse);
    expect(
      _read('$_mainKotlin/MainActivity.kt'),
      contains(
        'AppUpdateChannel(this).register(flutterEngine.dartExecutor.binaryMessenger)',
      ),
    );

    final String selfUpdateManifest = _read(_selfUpdateManifest);
    expect(
      RegExp(
        r'<uses-permission\s+android:name="android\.permission\.REQUEST_INSTALL_PACKAGES"\s*/>',
      ).hasMatch(selfUpdateManifest),
      isTrue,
    );
    final RegExpMatch? receiver = RegExp(
      r'<receiver\b([^>]*)>(.*?)</receiver>',
      dotAll: true,
    ).firstMatch(selfUpdateManifest);
    expect(receiver, isNotNull, reason: 'the receiver must be declared');
    expect(
      receiver!.group(1),
      contains('android:name=".UpdateReplacedReceiver"'),
    );
    expect(receiver.group(1), contains('android:exported="false"'));
    expect(
      receiver.group(2),
      contains(
        '<action android:name="android.intent.action.MY_PACKAGE_REPLACED" />',
      ),
    );

    final String installer = _read('$_selfUpdateKotlin/AppUpdateChannel.kt');
    for (final String part in <String>[
      _channelName,
      '"canSelfUpdate"',
      '"canRequestInstalls"',
      '"openInstallPermission"',
      '"install"',
      'Manifest.permission.REQUEST_INSTALL_PACKAGES',
      'canRequestPackageInstalls()',
      'Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES',
      'PackageInstaller.SessionParams.MODE_FULL_INSTALL',
      'setAppPackageName(context.packageName)',
      'PackageInstaller.STATUS_PENDING_USER_ACTION',
      'ContextCompat.RECEIVER_NOT_EXPORTED',
    ]) {
      expect(installer, contains(part));
    }
    final String replaced = _read(
      '$_selfUpdateKotlin/UpdateReplacedReceiver.kt',
    );
    for (final String part in <String>[
      'class UpdateReplacedReceiver : BroadcastReceiver()',
      'Intent.ACTION_MY_PACKAGE_REPLACED',
      'areNotificationsEnabled()',
      '"app_updates"',
      '"App updates"',
      'NotificationManager.IMPORTANCE_DEFAULT',
      '"Field Notes is updated"',
      r'"Tap to open version ${versionName(context)}."',
      'MainActivity::class.java',
    ]) {
      expect(replaced, contains(part));
    }

    final List<File> store = _sources('$_app/src/store');
    expect(store.map((File file) => file.path).toList(), <String>[
      '$_storeKotlin/AppUpdateChannel.kt',
    ]);
    final String stub = store.single.readAsStringSync();
    for (final String mark in _installerMarks) {
      expect(stub, isNot(contains(mark)));
    }
    expect(stub, contains(_channelName));
    expect(
      stub,
      contains(
        'CAN_SELF_UPDATE, CAN_REQUEST_INSTALLS -> result.success(false)',
      ),
    );
    expect(stub, contains('const val CAN_SELF_UPDATE = "canSelfUpdate"'));
    expect(
      stub,
      contains('const val CAN_REQUEST_INSTALLS = "canRequestInstalls"'),
    );
    expect(stub, contains('else -> result.error("unavailable"'));
    expect(_constructor(stub), _constructor(installer));
    expect(_constructor(stub), 'Activity');
    expect(stub, contains('fun register(messenger: BinaryMessenger)'));
    expect(installer, contains('fun register(messenger: BinaryMessenger)'));

    final String gradle = _read(_gradle);
    final RegExpMatch? property = RegExp(
      r'val (\w+) = providers\.gradleProperty\("fieldNotesSelfUpdate"\)\.orNull == "true"',
    ).firstMatch(gradle);
    expect(property, isNotNull, reason: 'the build must read the property');
    final String flag = property!.group(1)!;
    final int variants = gradle.indexOf('onVariants { variant ->');
    expect(variants, isNot(-1), reason: 'the build must configure variants');
    final String onVariants = _block(gradle, gradle.indexOf('{', variants));
    expect(
      onVariants,
      contains('variant.sources.kotlin ?: variant.sources.java'),
    );
    final int branch = onVariants.indexOf('if ($flag) {');
    expect(branch, isNot(-1), reason: 'the source sets depend on $flag');
    final int thenOpen = onVariants.indexOf('{', branch);
    final String selfUpdate = _block(onVariants, thenOpen);
    final int elseAt = thenOpen + selfUpdate.length + 2;
    expect(onVariants.substring(elseAt).trimLeft(), startsWith('else {'));
    final String otherwise = _block(
      onVariants,
      onVariants.indexOf('{', elseAt),
    );
    expect(
      selfUpdate,
      contains(
        'variant.sources.manifests.addStaticManifestFile("src/selfUpdate/AndroidManifest.xml")',
      ),
    );
    expect(
      selfUpdate,
      contains('addStaticSourceDirectory("src/selfUpdate/kotlin")'),
    );
    expect(selfUpdate, isNot(contains('src/store')));
    expect(otherwise, contains('addStaticSourceDirectory("src/store/kotlin")'));
    expect(otherwise, isNot(contains('src/selfUpdate')));
    expect(otherwise, isNot(contains('addStaticManifestFile')));
    expect('src/selfUpdate'.allMatches(gradle).length, 2);
    expect('src/store'.allMatches(gradle).length, 1);
    expect(gradle, isNot(contains('sourceSets')));
  });
}
